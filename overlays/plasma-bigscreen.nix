{
  mkKdeDerivation,
  lib,
  fetchFromGitLab,
  pkg-config,
  plasma-workspace,
  kdeconnect-kde,
  qtmultimedia,
  qtwayland,
  qtwebengine,
  qcoro,
  plasma-wayland-protocols,
  wayland,
  sdl3,
  libcec,
}:
mkKdeDerivation {
  pname = "plasma-bigscreen";
  version = "unstable-2026-09-01";

  src = fetchFromGitLab {
    domain = "invent.kde.org";
    owner = "plasma";
    repo = "plasma-bigscreen";
    rev = "d08c7701692c5c96b5aa7e50545bae09f543e39b";
    hash = "sha256-eWq2p2LhVOPP6Ax/Te6bByWW36WzltWBr2eEEcU/Q8o=";
  };

  extraNativeBuildInputs = [ pkg-config ];

  extraBuildInputs = [
    # The launcher imports the org.kde.kdeconnect QML module at configure time
    kdeconnect-kde
    qtmultimedia
    qtwayland
    qtwebengine
    qcoro
    plasma-wayland-protocols
    wayland
    sdl3
    libcec
  ];

  # Match project version to installed Plasma release so cmake version checks pass
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail 'set(PROJECT_VERSION "6.7.80")' \
                     'set(PROJECT_VERSION "${plasma-workspace.version}")'

    # Upstream references a nonexistent startplasma-waylandsession binary.
    # Fix this in the cmake template (before @KDE_INSTALL_FULL_LIBEXECDIR@ is substituted).
    substituteInPlace bin/plasma-bigscreen-wayland.in \
      --replace-fail \
        'startplasma-wayland --xwayland --libinput --exit-with-session=@KDE_INSTALL_FULL_LIBEXECDIR@/startplasma-waylandsession' \
        'startplasma-wayland'
  '';

  # FIXME: work around Qt 6.10 cmake API changes
  cmakeFlags = [ "-DQT_FIND_PRIVATE_MODULES=1" ];

  # QML lint fails on missing runtime-only imports (org.kde.private.biglauncher)
  # that are only available inside a running Plasma session
  dontQmlLint = true;

  postFixup = ''
    # Session .desktop references $out/libexec/plasma-dbus-run-session-if-needed
    # but the binary lives in plasma-workspace
    substituteInPlace "$out/share/wayland-sessions/plasma-bigscreen-wayland.desktop" \
      --replace-fail \
        "$out/libexec/plasma-dbus-run-session-if-needed" \
        "${plasma-workspace}/libexec/plasma-dbus-run-session-if-needed"

  '';

  passthru.providedSessions = [ "plasma-bigscreen-wayland" ];

  meta.license = with lib.licenses; [ gpl2Plus ];
}
