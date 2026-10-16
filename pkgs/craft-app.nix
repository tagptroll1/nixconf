# Shared builder for the storytold Crafting Apps (photocraft, vectorcraft, ...):
# same Cargo workspace layout, packaging/linux files and runtime needs.
# Lives outside modules/ so import-tree and the Packages menu skip it.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  pkg-config,
  wayland,
  libxkbcommon,
  vulkan-loader,
  libGL,
  libx11,
  libxcursor,
  libxi,
  libxcb,
}:
{
  pname,
  version,
  hash,
  cargoHash,
  description,
  buildFeatures ? [ ],
  buildInputs ? [ ],
}:
rustPlatform.buildRustPackage {
  inherit
    pname
    version
    cargoHash
    buildFeatures
    buildInputs
    ;

  src = fetchFromGitHub {
    owner = "storytold";
    repo = pname;
    tag = "v${version}";
    inherit hash;
  };

  # Same pair upstream release builds ship.
  cargoBuildFlags = [
    "-p"
    pname
    "-p"
    "${pname}-cli"
  ];

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  # Suites want a display and external test corpora.
  doCheck = false;

  postInstall = ''
    id=ai.storyteller.${pname}
    install -Dm644 packaging/linux/$id.desktop $out/share/applications/$id.desktop
    install -Dm644 packaging/linux/$id.mime.xml $out/share/mime/packages/$id.xml
    mkdir -p $out/share/icons
    cp -R assets/app-icon/hicolor $out/share/icons/
  '';

  # winit/wgpu dlopen these. LD_LIBRARY_PATH rather than rpath: the apps' own
  # startup probe only searches there, and fails the Xwayland fallback without it.
  # Xwayland always: winit 0.30 has no Wayland drag-and-drop.
  postFixup = ''
    wrapProgram $out/bin/${pname} --unset WAYLAND_DISPLAY --prefix LD_LIBRARY_PATH : ${
      lib.makeLibraryPath [
        wayland
        libxkbcommon
        vulkan-loader
        libGL
        libx11
        libxcursor
        libxi
        libxcb
      ]
    }
  '';

  meta = {
    inherit description;
    homepage = "https://github.com/storytold/${pname}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = pname;
    platforms = lib.platforms.linux;
  };
}
