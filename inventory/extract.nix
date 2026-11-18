# Pure data extraction for the service inventory page. Reads every machine's
# evaluated NixOS configuration plus the DNS zone definitions and returns plain
# data (no derivations) that `default.nix` serialises to JSON.
#
# Virtual-host `root` paths are deliberately never read: the host that serves
# this page points its own vhost root at the generated derivation, and reading
# it from here would make the evaluation depend on itself.
{ lib, nixosConfigurations, zones }:

let
  inherit (lib)
    attrByPath attrNames concatMap elem filter filterAttrs findFirst hasPrefix
    hasSuffix isAttrs isBool isInt isString mapAttrs mapAttrsToList optional
    optionalAttrs removeSuffix sort splitString unique;

  configs = mapAttrs (_: c: c.config) nixosConfigurations;
  optionsOf = mapAttrs (_: c: c.options) nixosConfigurations;

  # ---------------------------------------------------------------- DNS ----

  zoneNames = attrNames zones;
  stripDot = removeSuffix ".";

  # Longest zone that is a suffix of the name, or null when no managed zone
  # covers it (e.g. a bare hostname or a *.ts.net MagicDNS name).
  zoneOf = fqdn:
    let
      matches = filter (z: fqdn == z || hasSuffix ".${z}" fqdn) zoneNames;
      longestFirst = sort (a: b: builtins.stringLength a > builtins.stringLength b) matches;
    in
    if longestFirst == [ ] then null else builtins.head longestFirst;

  relName = fqdn: zone: if fqdn == zone then "@" else removeSuffix ".${zone}" fqdn;

  # Wildcard label that would cover a relative name: "grafana.kif" -> "*.kif".
  wildcardOf = rel:
    let parts = splitString "." rel; in
    if rel == "@" then null
    else "*" + (if builtins.length parts > 1 then "." + lib.concatStringsSep "." (builtins.tail parts) else "");

  recordsFor = zone: rel: types:
    filter (r: r.name == rel && elem r.type types) zones.${zone}.records;

  cnameTarget = zone: r:
    let t = stripDot r.target; in
    if t == "@" then zone
    else if zoneOf t != null then t
    else "${t}.${zone}";

  # Resolve a name through the managed zones, following CNAMEs.
  resolve = fqdn: depth:
    let
      zone = zoneOf fqdn;
      rel = relName fqdn zone;
      exact = recordsFor zone rel [ "A" "AAAA" "CNAME" ];
      wild = if wildcardOf rel == null then [ ] else recordsFor zone (wildcardOf rel) [ "A" "AAAA" "CNAME" ];
      recs = if exact != [ ] then exact else wild;
      cnames = filter (r: r.type == "CNAME") recs;
      addrs = filter (r: r.type != "CNAME") recs;
    in
    if zone == null then { managed = false; addresses = [ ]; chain = [ ]; wildcard = false; }
    else if cnames != [ ] && depth < 5 then
      let
        target = cnameTarget zone (builtins.head cnames);
        next = resolve target (depth + 1);
      in
      next // { managed = true; chain = [ target ] ++ next.chain; }
    else {
      managed = true;
      addresses = map (r: r.value) addrs;
      chain = [ ];
      wildcard = exact == [ ] && wild != [ ];
    };

  # ------------------------------------------------------------ addresses ----

  isTailnetIP = ip:
    let
      octets = splitString "." ip;
      second = lib.toInt (builtins.elemAt octets 1);
    in
    builtins.length octets == 4 && builtins.head octets == "100" && second >= 64 && second <= 127;

  isPrivateIP = ip: hasPrefix "192.168." ip || hasPrefix "10." ip || hasPrefix "172.16." ip || hasPrefix "fd" ip;
  isGlobalIPv6 = ip: lib.hasInfix ":" ip && !hasPrefix "fd" ip && !hasPrefix "fe80" ip && ip != "::1";

  tailscaleIPFromDNS = name:
    let
      hits = concatMap
        (zone: map (r: r.value)
          (filter (r: r.type == "A" && (r.name == name || r.name == "*.${name}") && isTailnetIP r.value)
            zones.${zone}.records))
        zoneNames;
    in
    if hits == [ ] then null else builtins.head hits;

  machineTailscaleIP = name: cfg:
    let fromNginx = attrByPath [ "services" "nginx" "tailscaleListenAddress" ] null cfg; in
    if fromNginx != null then fromNginx else tailscaleIPFromDNS name;

  publicIPs = filterAttrs (_: ip: ip != null) (mapAttrs (_: cfg: cfg.thisMachine.config.publicIP) configs);
  tailscaleIPs = filterAttrs (_: ip: ip != null) (mapAttrs machineTailscaleIP configs);

  ownerOf = ip: table:
    let hits = attrNames (filterAttrs (_: v: v == ip) table); in
    if hits == [ ] then null else builtins.head hits;

  classifyAddress = ip:
    let
      pub = ownerOf ip publicIPs;
      ts = ownerOf ip tailscaleIPs;
    in
    {
      address = ip;
      kind =
        if pub != null || isGlobalIPv6 ip then "public"
        else if ts != null || isTailnetIP ip then "tailnet"
        else if isPrivateIP ip then "lan"
        else "other";
      machine = if pub != null then pub else ts;
    };

  dnsFor = fqdn:
    let r = resolve fqdn 0; in
    r // { addresses = map classifyAddress r.addresses; };

  # ---------------------------------------------------------------- nginx ----

  firewallOf = cfg:
    let fw = cfg.networking.firewall; in
    {
      inherit (fw) enable allowedTCPPorts allowedUDPPorts allowedTCPPortRanges allowedUDPPortRanges trustedInterfaces;
      interfaces = mapAttrs
        (_: i: { inherit (i) allowedTCPPorts allowedUDPPorts allowedTCPPortRanges allowedUDPPortRanges; })
        fw.interfaces;
    };

  # Which network paths can reach a vhost's listener. Trusted interfaces
  # bypass the firewall, so anything bound to all addresses is reachable over
  # them regardless of the port lists.
  vhostExposure = cfg: v:
    let
      fw = firewallOf cfg;
      publicIP = cfg.thisMachine.config.publicIP;
      webOpen = ports: elem 80 ports || elem 443 ports;
      openInterfaces = attrNames (filterAttrs (_: i: webOpen i.allowedTCPPorts) fw.interfaces);
    in
    if v.tailscaleOnly then { kind = "tailnet"; via = [ "tailscale listen address" ]; }
    else if v.listenAddresses != [ ] then { kind = "custom"; via = v.listenAddresses; }
    else if !fw.enable || webOpen fw.allowedTCPPorts then
      { kind = if publicIP != null then "internet" else "lan"; via = [ "all interfaces" ]; }
    else {
      kind = "trusted";
      via = map (i: "${i} (trusted)") fw.trustedInterfaces ++ openInterfaces;
    };

  locationData = path: l: {
    inherit path;
    proxyPass = l.proxyPass;
    proxyWebsockets = l.proxyWebsockets;
    return = l.return;
    alias = l.alias;
    basicAuth = l.basicAuthFile != null || l.basicAuth != { };
  };

  vhostData = cfg: name: v: {
    inherit name;
    inherit (v) serverAliases listenAddresses forceSSL addSSL onlySSL enableACME useACMEHost http2 http3 quic rejectSSL globalRedirect;
    tls = v.forceSSL || v.addSSL || v.onlySSL;
    isDefault = v.default;
    tailscaleOnly = v.tailscaleOnly;
    tailscaleAuth = {
      inherit (v.tailscaleAuth) enable allowedTags;
    };
    basicAuth = v.basicAuthFile != null || v.basicAuth != { };
    locations = mapAttrsToList locationData v.locations;
    exposure = vhostExposure cfg v;
    dns = dnsFor name;
  };

  nginxData = cfg:
    let ng = cfg.services.nginx; in
    if !ng.enable then null else {
      version = ng.package.version;
      inherit (ng) openFirewall tailscaleListenAddress;
      tailscaleAuth = { inherit (ng.tailscaleAuth) enable defaultAllowedTags expectedTailnet; };
      virtualHosts = mapAttrsToList (vhostData cfg) ng.virtualHosts;
    };

  # ------------------------------------------------------------- services ----

  # Enabled `services.<name>` entries, with a listening port when one of the
  # common option spellings exists. Best effort: a service with an unusual
  # option layout simply shows no port.
  portCandidates = [
    [ "port" ]
    [ "httpPort" ]
    [ "listenPort" ]
    [ "listenAddress" ]
    [ "settings" "port" ]
    [ "settings" "listen_port" ]
    [ "settings" "listen-http" ]
    [ "settings" "server" "http_port" ]
    [ "settings" "server" "HTTP_PORT" ]
    [ "settings" "web" "port" ]
    [ "config" "http" "server_port" ]
  ];

  # Each candidate is probed under tryEval: a removed option throws on read
  # even though its attribute path still exists.
  # Each candidate is probed under tryEval: a removed option throws on read
  # even though its attribute path still exists. Hidden (renamed alias)
  # options are skipped so the read never triggers their warning.
  candidateValue = opts: v: path:
    let
      hiddenAt = n:
        let o = attrByPath (lib.take n path) null opts; in
        lib.isOption o && (o.visible or true) == false;
      hidden = lib.any hiddenAt (lib.range 1 (builtins.length path));
      r = builtins.tryEval (
        let raw = attrByPath path null v; in
        if !hidden && (isInt raw || isString raw) then raw else null
      );
    in
    if r.success then r.value else null;

  servicePort = opts: v: findFirst (x: x != null) null (map (candidateValue opts v) portCandidates);

  # Walks the option declarations rather than the config so renamed and alias
  # options (hidden, and they warn or abort when read) are never touched.
  serviceEnabled = cfg: name: opt:
    let
      declared = isAttrs opt && (opt ? enable) && lib.isOption opt.enable && (opt.enable.visible or true) != false;
      r = builtins.tryEval (declared && isBool cfg.services.${name}.enable && cfg.services.${name}.enable);
    in
    r.success && r.value;

  servicesData = name: cfg:
    let
      enabled = mapAttrs (n: _: cfg.services.${n}) (filterAttrs (serviceEnabled cfg) optionsOf.${name}.services);
      generic = mapAttrsToList (n: v: { name = n; port = servicePort optionsOf.${name}.services.${n} v; }) enabled;
      nodeExporter = optional (attrByPath [ "services" "prometheus" "exporters" "node" "enable" ] false cfg) {
        name = "prometheus.exporters.node";
        port = cfg.services.prometheus.exporters.node.port;
      };
    in
    generic ++ nodeExporter;

  # ----------------------------------------------------------- containers ----

  containersData = cfg:
    (mapAttrsToList
      (name: ct: {
        inherit name;
        kind = "nspawn";
        ip = ct.localAddress;
        hostAddress = ct.hostAddress;
        autoStart = ct.autoStart;
        forwardPorts = map (p: { inherit (p) hostPort containerPort protocol; }) ct.forwardPorts;
      })
      cfg.containers)
    ++ (mapAttrsToList
      (name: ct: {
        inherit name;
        kind = "oci";
        image = ct.image;
        ports = ct.ports;
      })
      cfg.virtualisation.oci-containers.containers);

  piaData = cfg:
    let pia = cfg.pia-vpn; in
    if !pia.enable then null else {
      inherit (pia) serverLocation bridgeName subnet vpnAddress proxyPort;
      containers = mapAttrsToList
        (name: c: {
          inherit name;
          ip = c.ip;
          receiveForwardedPort = c.receiveForwardedPort;
        })
        pia.containers;
    };

  workspacesData = cfg:
    let ws = cfg.sandboxed-workspace; in
    if !ws.enable then [ ] else
    mapAttrsToList
      (name: w: { inherit name; inherit (w) type ip autoStart passHostGpu; })
      ws.workspaces;

  # ------------------------------------------------------------ monitoring ----

  gatusEndpoints = concatMap
    (cfg:
      if cfg.services.gatus.enable then
        map (e: { inherit (e) name group url; }) cfg.services.gatus.settings.endpoints
      else [ ])
    (builtins.attrValues configs);

  dashyItems = concatMap
    (cfg:
      if cfg.services.dashy.enable then
        concatMap
          (section: map (i: { inherit (i) title url; section = section.name; }) section.items)
          cfg.services.dashy.settings.sections
      else [ ])
    (builtins.attrValues configs);

  # -------------------------------------------------------------- machines ----

  machineData = name: cfg:
    let props = cfg.thisMachine.config; in
    {
      inherit name;
      inherit (props) hostNames arch systemRoles publicIP;
      tailscaleIP = attrByPath [ name ] null tailscaleIPs;
      tailnetName = if cfg.services.tailscale.enable then "${name}.${cfg.services.tailscale.tailnetDomain}" else null;
      remoteUnlock =
        if props.remoteUnlock == null then null
        else { inherit (props.remoteUnlock) clearnetHost onionHost; };
      nixosRelease = cfg.system.nixos.release;
      kernel = cfg.boot.kernelPackages.kernel.version;
      sshPorts = cfg.services.openssh.ports;
      firewall = firewallOf cfg;
      nginx = nginxData cfg;
      services = servicesData name cfg;
      containers = containersData cfg;
      piaVpn = piaData cfg;
      workspaces = workspacesData cfg;
      mail =
        if cfg.mailserver.enable then { inherit (cfg.mailserver) fqdn domains; } else null;
    };

  dnsZonesData = mapAttrs
    (zone: z: map
      (r: {
        inherit (r) name type ttl;
        value = r.value or r.target or null;
        priority = r.priority or null;
        port = r.port or null;
        target = if r ? value then classifyAddress r.value else null;
      })
      (filter (r: r.type != "TXT") z.records))
    zones;
in
{
  machines = mapAttrsToList machineData configs;
  gatus = gatusEndpoints;
  dashy = dashyItems;
  dns = dnsZonesData;
}
