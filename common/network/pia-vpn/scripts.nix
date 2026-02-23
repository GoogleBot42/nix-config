let
  caPath = ./ca.rsa.4096.crt;
in

# Bash function library for PIA VPN WireGuard operations.
# All PIA API calls accept an optional $proxy variable:
#   proxy="http://10.100.0.1:8888" fetchPIAToken
# When $proxy is set, curl uses --proxy "$proxy"; otherwise direct connection.

# Reference materials:
#   https://serverlist.piaservers.net/vpninfo/servers/v6
#   https://github.com/pia-foss/manual-connections
#   https://github.com/thrnz/docker-wireguard-pia/blob/master/extra/wg-gen.sh
#   https://www.wireguard.com/netns/#ordinary-containerization

{
  scriptCommon = ''
    proxy_args() {
      if [[ -n "''${proxy:-}" ]]; then
        echo "--proxy $proxy"
      fi
    }

    fetchPIAToken() {
      local PIA_USER PIA_PASS resp
      echo "Reading PIA credentials..."
      PIA_USER=$(sed '1q;d' /run/agenix/pia-login.conf)
      PIA_PASS=$(sed '2q;d' /run/agenix/pia-login.conf)
      echo "Requesting PIA authentication token..."
      resp=$(curl -s $(proxy_args) -u "$PIA_USER:$PIA_PASS" \
        "https://www.privateinternetaccess.com/gtoken/generateToken")
      PIA_TOKEN=$(echo "$resp" | jq -r '.token')
      if [[ -z "$PIA_TOKEN" || "$PIA_TOKEN" == "null" ]]; then
        echo "ERROR: Failed to fetch PIA token: $resp" >&2
        return 1
      fi
      echo "PIA token acquired"
    }

    choosePIAServer() {
      local serverLocation=$1
      local servers servers_json totalservers serverindex
      servers=$(mktemp)
      servers_json=$(mktemp)
      echo "Fetching PIA server list..."
      curl -s $(proxy_args) \
        "https://serverlist.piaservers.net/vpninfo/servers/v6" > "$servers"
      head -n 1 "$servers" | tr -d '\n' > "$servers_json"

      echo "Available location ids:"
      jq '.regions | .[] | {name, id, port_forward}' "$servers_json"

      totalservers=$(jq -r \
        '.regions | .[] | select(.id=="'"$serverLocation"'") | .servers.wg | length' \
        "$servers_json")
      if ! [[ "$totalservers" =~ ^[0-9]+$ ]] || [ "$totalservers" -eq 0 ] 2>/dev/null; then
        echo "ERROR: Location \"$serverLocation\" not found." >&2
        rm -f "$servers_json" "$servers"
        return 1
      fi
      echo "Found $totalservers WireGuard servers in region '$serverLocation'"
      serverindex=$(( RANDOM % totalservers ))

      WG_HOSTNAME=$(jq -r \
        '.regions | .[] | select(.id=="'"$serverLocation"'") | .servers.wg | .['"$serverindex"'].cn' \
        "$servers_json")
      WG_SERVER_IP=$(jq -r \
        '.regions | .[] | select(.id=="'"$serverLocation"'") | .servers.wg | .['"$serverindex"'].ip' \
        "$servers_json")
      WG_SERVER_PORT=$(jq -r '.groups.wg | .[0] | .ports | .[0]' "$servers_json")

      rm -f "$servers_json" "$servers"
      echo "Selected server $serverindex/$totalservers: $WG_HOSTNAME ($WG_SERVER_IP:$WG_SERVER_PORT)"
    }

    generateWireguardKey() {
      PRIVATE_KEY=$(wg genkey)
      PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)
      echo "Generated WireGuard keypair"
    }

    authorizeKeyWithPIAServer() {
      local addKeyResponse
      echo "Sending addKey request to $WG_HOSTNAME ($WG_SERVER_IP:$WG_SERVER_PORT)..."
      addKeyResponse=$(curl -s -G $(proxy_args) \
        --connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" \
        --cacert "${caPath}" \
        --data-urlencode "pt=$PIA_TOKEN" \
        --data-urlencode "pubkey=$PUBLIC_KEY" \
        "https://$WG_HOSTNAME:$WG_SERVER_PORT/addKey")
      local status
      status=$(echo "$addKeyResponse" | jq -r '.status')
      if [[ "$status" != "OK" ]]; then
        echo "ERROR: addKey failed: $addKeyResponse" >&2
        return 1
      fi
      MY_IP=$(echo "$addKeyResponse" | jq -r '.peer_ip')
      WG_SERVER_PUBLIC_KEY=$(echo "$addKeyResponse" | jq -r '.server_key')
      WG_SERVER_PORT=$(echo "$addKeyResponse" | jq -r '.server_port')
      echo "Key authorized — assigned VPN IP: $MY_IP, server port: $WG_SERVER_PORT"
    }

    writeWireguardQuickFile() {
      local wgFile=$1
      local listenPort=$2
      rm -f "$wgFile"
      touch "$wgFile"
      chmod 700 "$wgFile"
      cat > "$wgFile" <<WGEOF
    [Interface]
    PrivateKey = $PRIVATE_KEY
    ListenPort = $listenPort
    [Peer]
    PersistentKeepalive = 25
    PublicKey = $WG_SERVER_PUBLIC_KEY
    AllowedIPs = 0.0.0.0/0
    Endpoint = $WG_SERVER_IP:$WG_SERVER_PORT
    WGEOF
      echo "Wrote WireGuard config to $wgFile (listen=$listenPort)"
    }

    writeChosenServerToFile() {
      local serverFile=$1
      jq -n \
        --arg hostname "$WG_HOSTNAME" \
        --arg ip "$WG_SERVER_IP" \
        --arg port "$WG_SERVER_PORT" \
        '{hostname: $hostname, ip: $ip, port: $port}' > "$serverFile"
      chmod 700 "$serverFile"
      echo "Wrote server info to $serverFile"
    }

    loadChosenServerFromFile() {
      local serverFile=$1
      WG_HOSTNAME=$(jq -r '.hostname' "$serverFile")
      WG_SERVER_IP=$(jq -r '.ip' "$serverFile")
      WG_SERVER_PORT=$(jq -r '.port' "$serverFile")
      echo "Loaded server info from $serverFile: $WG_HOSTNAME ($WG_SERVER_IP:$WG_SERVER_PORT)"
    }

    connectToServer() {
      local wgFile=$1
      local interfaceName=$2

      echo "Applying WireGuard config to $interfaceName..."
      wg setconf "$interfaceName" "$wgFile"
      ip -4 address add "$MY_IP" dev "$interfaceName"
      ip link set mtu 1420 up dev "$interfaceName"
      echo "WireGuard interface $interfaceName is up with IP $MY_IP"
    }

    reservePortForward() {
      local payload_and_signature
      echo "Requesting port forward signature from $WG_HOSTNAME..."
      payload_and_signature=$(curl -s -m 5 $(proxy_args) \
        --connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" \
        --cacert "${caPath}" \
        -G --data-urlencode "token=$PIA_TOKEN" \
        "https://$WG_HOSTNAME:19999/getSignature")
      local status
      status=$(echo "$payload_and_signature" | jq -r '.status')
      if [[ "$status" != "OK" ]]; then
        echo "ERROR: getSignature failed: $payload_and_signature" >&2
        return 1
      fi
      PORT_SIGNATURE=$(echo "$payload_and_signature" | jq -r '.signature')
      PORT_PAYLOAD=$(echo "$payload_and_signature" | jq -r '.payload')
      PORT=$(echo "$PORT_PAYLOAD" | base64 -d | jq -r '.port')
      echo "Port forward reserved: port $PORT"
    }

    writePortRenewalFile() {
      local portRenewalFile=$1
      jq -n \
        --arg signature "$PORT_SIGNATURE" \
        --arg payload "$PORT_PAYLOAD" \
        '{signature: $signature, payload: $payload}' > "$portRenewalFile"
      chmod 700 "$portRenewalFile"
      echo "Wrote port renewal data to $portRenewalFile"
    }

    readPortRenewalFile() {
      local portRenewalFile=$1
      PORT_SIGNATURE=$(jq -r '.signature' "$portRenewalFile")
      PORT_PAYLOAD=$(jq -r '.payload' "$portRenewalFile")
      echo "Loaded port renewal data from $portRenewalFile"
    }

    refreshPIAPort() {
      local bindPortResponse
      echo "Refreshing port forward binding with $WG_HOSTNAME..."
      bindPortResponse=$(curl -Gs -m 5 \
        --connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" \
        --cacert "${caPath}" \
        --data-urlencode "payload=$PORT_PAYLOAD" \
        --data-urlencode "signature=$PORT_SIGNATURE" \
        "https://$WG_HOSTNAME:19999/bindPort")
      echo "bindPort response: $bindPortResponse"
    }
  '';
}
