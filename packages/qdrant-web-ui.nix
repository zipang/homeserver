{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "qdrant-web-ui";
  version = "0.2.20";

  # Upstream publishes the built dashboard as a zip asset. Using it avoids a
  # full npm build while keeping the exact bundle that matches Qdrant 1.20.0.
  # The archive contains a single top-level "dist/" directory.
  src = fetchurl {
    url = "https://github.com/qdrant/qdrant-web-ui/releases/download/v${finalAttrs.version}/dist-qdrant.zip";
    hash = "sha256-Mx1vg+48DncaArgOxY3zhX5+urmbfL3RoVviBakhXT0=";
  };

  nativeBuildInputs = [ unzip ];

  dontBuild = true;

  # The archive has a single top-level "dist/" directory, which unpackPhase
  # detects as sourceRoot and cd's into. Install from the working directory.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r . $out/
    runHook postInstall
  '';

  meta = {
    description = "Qdrant Web UI, pinned to the version aligned with Qdrant 1.20.0";
    homepage = "https://github.com/qdrant/qdrant-web-ui";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
})
