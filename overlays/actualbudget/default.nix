{ lib
, buildNpmPackage
, fetchFromGitHub
, python3
, nodejs
, runtimeShell
}:
buildNpmPackage rec {
  pname = "actual-server";
  version = "24.3.0";

  src = fetchFromGitHub {
    owner = "actualbudget";
    repo = pname;
    rev = "refs/tags/v${version}";
    hash = "sha256-y51Dhdn84AWR/gM4LnAzvBIBpvKwUiclnPnwzkRoJ0I=";
  };

  npmDepsHash = "sha256-/UM2Tz8t4hi621HtXSu0LTDIzZ9SWMqKXqKfPwkdpE8=";

  patches = [
    ./migrations-should-use-pkg-path.patch
  ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  postInstall = ''
    mkdir -p $out/bin
    cat <<EOF > $out/bin/actual-server
    #!${runtimeShell}
    exec ${nodejs}/bin/node $out/lib/node_modules/actual-sync/app.js "\$@"
    EOF
    chmod +x $out/bin/actual-server
  '';
}
