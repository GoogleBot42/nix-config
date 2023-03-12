#!/bin/sh

# TODO allow adding custom parameters to ht_capab, vht_capab
# TODO detect bad channel numbers (preferably not at runtime)
# TODO error if 160mhz is not supported
# TODO 'b' only goes up to 40mhz

# gets the phy number using the input interface
# Ex: get_phy_number("wlan0") -> "1"
get_phy_number() {
  local interface=$1
  phy=$(iw dev "$interface" info | awk '/phy/ {gsub(/#/,"");print $2}')
  if [[ -z "$phy" ]]; then
    echo "Error: interface not found" >&2
    exit 1
  fi
  phy=phy$phy
}

get_ht_cap_mask() {
  ht_cap_mask=0

  for cap in $(iw phy "$phy" info | grep 'Capabilities:' | cut -d: -f2); do
    ht_cap_mask="$(($ht_cap_mask | $cap))"
  done

  local cap_rx_stbc
  cap_rx_stbc=$((($ht_cap_mask >> 8) & 3))
  ht_cap_mask="$(( ($ht_cap_mask & ~(0x300)) | ($cap_rx_stbc << 8) ))"
}

get_vht_cap_mask() {
  vht_cap_mask=0
  for cap in $(iw phy "$phy" info | awk -F "[()]" '/VHT Capabilities/ { print $2 }'); do
    vht_cap_mask="$(($vht_cap_mask | $cap))"
  done

  local cap_rx_stbc
  cap_rx_stbc=$((($vht_cap_mask >> 8) & 7))
  vht_cap_mask="$(( ($vht_cap_mask & ~(0x700)) | ($cap_rx_stbc << 8) ))"
}

mac80211_add_capabilities() {
  local __var="$1"; shift
  local __mask="$1"; shift
  local __out= oifs

  oifs="$IFS"
  IFS=:
  for capab in "$@"; do
    set -- $capab
    [ "$(($4))" -gt 0 ] || continue
    [ "$(($__mask & $2))" -eq "$((${3:-$2}))" ] || continue
    __out="$__out[$1]"
  done
  IFS="$oifs"

  export -n -- "$__var=$__out"
}

add_special_ht_capabilities() {
  case "$hwmode" in
    a)
      case "$(( ($channel / 4) % 2 ))" in
        1) ht_capab="$ht_capab[HT40+]";;
        0) ht_capab="$ht_capab[HT40-]";;
      esac
    ;;
    *)
      if [ "$channel" -lt 7 ]; then
        ht_capab="$ht_capab[HT40+]"
      else
        ht_capab="$ht_capab[HT40-]"
      fi
    ;;
  esac
}

add_special_vht_capabilities() {
  local cap_ant
  [ "$(($vht_cap_mask & 0x800))" -gt 0 ] && {
    cap_ant="$(( ( ($vht_cap_mask >> 16) & 3 ) + 1 ))"
    [ "$cap_ant" -gt 1 ] && vht_capab="$vht_capab[SOUNDING-DIMENSION-$cap_ant]"
  }

  [ "$(($vht_cap_mask & 0x1000))" -gt 0 ] && {
    cap_ant="$(( ( ($vht_cap_mask >> 13) & 3 ) + 1 ))"
    [ "$cap_ant" -gt 1 ] && vht_capab="$vht_capab[BF-ANTENNA-$cap_ant]"
  }

  if [ "$(($vht_cap_mask & 12))" -eq 4 ]; then
    vht_capab="$vht_capab[VHT160]"
  fi

  local vht_max_mpdu_hw=3895
  [ "$(($vht_cap_mask & 3))" -ge 1 ] && \
    vht_max_mpdu_hw=7991
  [ "$(($vht_cap_mask & 3))" -ge 2 ] && \
    vht_max_mpdu_hw=11454
  [ "$vht_max_mpdu_hw" != 3895 ] && \
    vht_capab="$vht_capab[MAX-MPDU-$vht_max_mpdu_hw]"

  # maximum A-MPDU length exponent
  local vht_max_a_mpdu_len_exp_hw=0
  [ "$(($vht_cap_mask & 58720256))" -ge 8388608 ] && \
    vht_max_a_mpdu_len_exp_hw=1
  [ "$(($vht_cap_mask & 58720256))" -ge 16777216 ] && \
    vht_max_a_mpdu_len_exp_hw=2
  [ "$(($vht_cap_mask & 58720256))" -ge 25165824 ] && \
    vht_max_a_mpdu_len_exp_hw=3
  [ "$(($vht_cap_mask & 58720256))" -ge 33554432 ] && \
    vht_max_a_mpdu_len_exp_hw=4
  [ "$(($vht_cap_mask & 58720256))" -ge 41943040 ] && \
    vht_max_a_mpdu_len_exp_hw=5
  [ "$(($vht_cap_mask & 58720256))" -ge 50331648 ] && \
    vht_max_a_mpdu_len_exp_hw=6
  [ "$(($vht_cap_mask & 58720256))" -ge 58720256 ] && \
    vht_max_a_mpdu_len_exp_hw=7
  vht_capab="$vht_capab[MAX-A-MPDU-LEN-EXP$vht_max_a_mpdu_len_exp_hw]"

  local vht_link_adapt_hw=0
  [ "$(($vht_cap_mask & 201326592))" -ge 134217728 ] && \
    vht_link_adapt_hw=2
  [ "$(($vht_cap_mask & 201326592))" -ge 201326592 ] && \
    vht_link_adapt_hw=3
  [ "$vht_link_adapt_hw" != 0 ] && \
    vht_capab="$vht_capab[VHT-LINK-ADAPT-$vht_link_adapt_hw]"
}

calculate_channel_offsets() {
  vht_oper_chwidth=0
  vht_oper_centr_freq_seg0_idx=

  local idx="$channel"
  case "$channelWidth" in
    40)
      case "$(( ($channel / 4) % 2 ))" in
        1) idx=$(($channel + 2));;
        0) idx=$(($channel - 2));;
      esac
      vht_oper_centr_freq_seg0_idx=$idx
    ;;
    80)
      case "$(( ($channel / 4) % 4 ))" in
        1) idx=$(($channel + 6));;
        2) idx=$(($channel + 2));;
        3) idx=$(($channel - 2));;
        0) idx=$(($channel - 6));;
      esac
      vht_oper_chwidth=1
      vht_oper_centr_freq_seg0_idx=$idx
    ;;
    160)
      case "$channel" in
        36|40|44|48|52|56|60|64) idx=50;;
        100|104|108|112|116|120|124|128) idx=114;;
      esac
      vht_oper_chwidth=2
      vht_oper_centr_freq_seg0_idx=$idx
    ;;
  esac

  he_oper_chwidth=$vht_oper_chwidth
  he_oper_centr_freq_seg0_idx=$vht_oper_centr_freq_seg0_idx
}

interface=$1
channel=$2
hwmode=$3
channelWidth=$4

get_phy_number $interface
get_ht_cap_mask
get_vht_cap_mask

mac80211_add_capabilities vht_capab $vht_cap_mask \
  RXLDPC:0x10::1 \
  SHORT-GI-80:0x20::1 \
  SHORT-GI-160:0x40::1 \
  TX-STBC-2BY1:0x80::1 \
  SU-BEAMFORMER:0x800::1 \
  SU-BEAMFORMEE:0x1000::1 \
  MU-BEAMFORMER:0x80000::1 \
  MU-BEAMFORMEE:0x100000::1 \
  VHT-TXOP-PS:0x200000::1 \
  HTC-VHT:0x400000::1 \
  RX-ANTENNA-PATTERN:0x10000000::1 \
  TX-ANTENNA-PATTERN:0x20000000::1 \
  RX-STBC-1:0x700:0x100:1 \
  RX-STBC-12:0x700:0x200:1 \
  RX-STBC-123:0x700:0x300:1 \
  RX-STBC-1234:0x700:0x400:1 \

mac80211_add_capabilities ht_capab $ht_cap_mask \
  LDPC:0x1::1 \
  GF:0x10::1 \
  SHORT-GI-20:0x20::1 \
  SHORT-GI-40:0x40::1 \
  TX-STBC:0x80::1 \
  RX-STBC1:0x300::1 \
  MAX-AMSDU-7935:0x800::1 \

  # TODO this is active when the driver doesn't support it?
  # DSSS_CCK-40:0x1000::1 \

  # TODO these are active when the driver doesn't support them?
  # RX-STBC1:0x300:0x100:1 \
  # RX-STBC12:0x300:0x200:1 \
  # RX-STBC123:0x300:0x300:1 \

add_special_ht_capabilities
add_special_vht_capabilities

echo ht_capab=$ht_capab
echo vht_capab=$vht_capab

if [ "$channelWidth" != "20" ]; then
  calculate_channel_offsets
  echo he_oper_chwidth=$he_oper_chwidth
  echo vht_oper_chwidth=$vht_oper_chwidth
  echo he_oper_centr_freq_seg0_idx=$he_oper_centr_freq_seg0_idx
  echo vht_oper_centr_freq_seg0_idx=$vht_oper_centr_freq_seg0_idx
fi