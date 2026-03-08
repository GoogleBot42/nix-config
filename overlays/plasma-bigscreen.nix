{
  mkKdeDerivation,
  lib,
  fetchFromGitLab,
  pkg-config,
  plasma-workspace,
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
  version = "unstable-2026-03-07";

  src = fetchFromGitLab {
    domain = "invent.kde.org";
    owner = "plasma";
    repo = "plasma-bigscreen";
    rev = "bd143fea7e386bac1652b8150a3ed3d5ef7cf93c";
    hash = "sha256-y439IX7e0+XqxqFj/4+P5le0hA7DiwA+smDsD0UH/fI=";
  };

  patches = [
    ../patches/plasma-bigscreen-input-handler-app-id.patch
  ];

  extraNativeBuildInputs = [ pkg-config ];

  extraBuildInputs = [
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
      --replace-fail 'set(PROJECT_VERSION "6.5.80")' \
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
