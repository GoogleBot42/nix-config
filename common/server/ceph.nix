{ config, lib, ... }:

with lib;
let
  cfg = config.ceph;
in {
  options.ceph = {
  };

  config = mkIf cfg.enable {
    # ceph.enable = true;
    
    ## S3 Object gateway
    #ceph.rgw.enable = true;
    #ceph.rgw.daemons = [
    #];

    # https://docs.ceph.com/en/latest/start/intro/

    # meta object storage daemon
    ceph.osd.enable = true;
    ceph.osd.daemons = [

    ];
    # monitor's ceph state
    ceph.mon.enable = true;
    ceph.mon.daemons = [

    ];
    # manage ceph
    ceph.mgr.enable = true;
    ceph.mgr.daemons = [

    ];
    # metadata server
    ceph.mds.enable = true;
    ceph.mds.daemons = [

    ];
    ceph.global.fsid = "925773DC-D95F-476C-BBCD-08E01BF0865F";

  };
}