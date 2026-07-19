{ lib
, buildGoModule
, fetchFromGitHub
, makeWrapper
}:

buildGoModule rec {
  pname = "pgs";
  version = "0-unstable-2026-07-18";

  src = fetchFromGitHub {
    owner = "picosh";
    repo = "pico";
    rev = "4902f05382c6a98b3e5390f75e60e568270ee4f0";
    hash = "sha256-fbNU/Doz3SGlq2zXmOXvT5XzfbgyAZ0qZz/L78lg3DM=";
  };

  vendorHash = "sha256-sjH/eTCGlHwLmMx+2aKLCxovQANN6eRMt1inEnH/Lbo=";

  patches = [ ./configurable-limits.patch ];

  subPackages = [ "cmd/pgs/standalone" ];

  nativeBuildInputs = [ makeWrapper ];

  ldflags = [ "-s" "-w" ];

  postInstall = ''
    install -D -m755 $GOPATH/bin/standalone $out/share/pgs/pgs
    mkdir -p $out/share/pgs/pkg/apps/pgs
    cp -r pkg/apps/pgs/html pkg/apps/pgs/public $out/share/pgs/pkg/apps/pgs/
    makeWrapper $out/share/pgs/pgs $out/bin/pgs
  '';

  meta = with lib; {
    description = "Self-hostable static site hosting service using SSH";
    homepage = "https://github.com/picosh/pico";
    license = licenses.mit;
    mainProgram = "pgs";
    platforms = platforms.linux;
  };
}
