# Nix-side wrapper for the PIA port refresh unit test. It builds the shared
# shell helpers, then runs the Bash test that stubs curl so retry and error
# handling can be exercised without contacting PIA.
{ pkgs }:
let
  scripts = import ../common/network/pia-vpn/scripts.nix;
  scriptCommonFile = pkgs.writeText "pia-vpn-script-common.sh" scripts.scriptCommon;
in
pkgs.runCommand "pia-vpn-port-refresh-check"
{
  nativeBuildInputs = [ pkgs.bash pkgs.gnugrep pkgs.jq ];
}
  ''
    cd ${../.}
    PIA_VPN_SCRIPT_COMMON_FILE=${scriptCommonFile} bash tests/pia-vpn-port-refresh.sh
    touch $out
  ''
