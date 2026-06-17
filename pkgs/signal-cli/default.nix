{
  stdenvNoCC,
  lib,
  fetchurl,
  makeWrapper,
  openjdk25_headless,
  libmatthew_java,
  dbus,
  dbus_java,
  versionCheckHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "signal-cli";
  version = "0.14.5";

  # Keep using the upstream release tarball here so we can hotfix Hermes
  # immediately without waiting for the newer nixpkgs packaging to land in our
  # pin.
  src = fetchurl {
    url = "https://github.com/AsamK/signal-cli/releases/download/v${finalAttrs.version}/signal-cli-${finalAttrs.version}.tar.gz";
    hash = "sha256-YtOOv+85iNePQ35zKBg7de5UnRETguZsGvcNPr0816c=";
  };

  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    libmatthew_java
    dbus
    dbus_java
  ];
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r lib $out/
    install -Dm755 bin/signal-cli -t $out/bin
  ''
  + (
    if stdenvNoCC.hostPlatform.isLinux then
      ''
        makeWrapper ${openjdk25_headless}/bin/java $out/bin/signal-cli \
          --set JAVA_HOME "${openjdk25_headless}" \
          --add-flags "--enable-native-access=ALL-UNNAMED" \
          --add-flags "-classpath '$out/lib/*:${libmatthew_java}/lib/jni'" \
          --add-flags "-Djava.library.path=${libmatthew_java}/lib/jni:${dbus_java}/share/java/dbus:$out/lib" \
          --add-flags "org.asamk.signal.Main"
      ''
    else
      ''
        wrapProgram $out/bin/signal-cli \
          --prefix PATH : ${lib.makeBinPath [ openjdk25_headless ]} \
          --set JAVA_HOME ${openjdk25_headless}
      ''
  )
  + ''
    runHook postInstall
  '';

  doInstallCheck = stdenvNoCC.hostPlatform.isLinux;

  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    homepage = "https://github.com/AsamK/signal-cli";
    description = "Command-line and dbus interface for communicating with the Signal messaging service";
    mainProgram = "signal-cli";
    changelog = "https://github.com/AsamK/signal-cli/blob/v${finalAttrs.version}/CHANGELOG.md";
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    license = lib.licenses.gpl3;
    maintainers = [ lib.maintainers.klea ];
    platforms = lib.platforms.all;
  };
})
