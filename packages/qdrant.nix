{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "qdrant";
  version = "1.20.0";

  # Qdrant publishes a prebuilt Rust binary for x86_64 Linux. It is linked
  # against the system glibc (GLIBC_2.39) and expects the usual ELF
  # interpreter, which NixOS does not provide. autoPatchelfHook rewrites both
  # the interpreter and the library paths to Nix store paths.
  src = fetchurl {
    url = "https://github.com/qdrant/qdrant/releases/download/v${finalAttrs.version}/qdrant-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-I2Hz3w3t/vMfVET58VvRXWtKbLpq2VLa7MX744Z8XuY=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  # Supplies libgcc_s.so.1, which the release binary needs.
  buildInputs = [ stdenv.cc.cc.lib ];

  # The release archive contains a single "qdrant" file at its root and no
  # directory. The default unpackPhase derives sourceRoot from the only
  # top-level directory and fails with "unpacker appears to have produced no
  # directories", so point it at the build directory explicitly.
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  # The binary is not stripped upstream; keep it that way for useful backtraces.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 qdrant $out/bin/qdrant
    runHook postInstall
  '';

  meta = {
    description = "Qdrant vector search engine, pinned to the version used by the RAG project";
    homepage = "https://github.com/qdrant/qdrant";
    license = lib.licenses.asl20;
    mainProgram = "qdrant";
    platforms = [ "x86_64-linux" ];
  };
})
