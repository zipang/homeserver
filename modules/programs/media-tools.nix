{ pkgs, ... }:

let
  av1-converter = pkgs.stdenv.mkDerivation {
    pname = "av1-converter";
    version = "1.0.0";

    src = ../../.;

    nativeBuildInputs = [ pkgs.bun pkgs.makeWrapper ];

    buildPhase = ''
      export HOME=$TMPDIR
      bun build ./scripts/av1-converter.ts --outfile av1-converter.js --target bun
    '';

    installPhase = ''
      mkdir -p $out/bin $out/share/av1-converter
      cp av1-converter.js $out/share/av1-converter/
      
      makeWrapper ${pkgs.bun}/bin/bun $out/bin/av1-converter \
        --add-flags $out/share/av1-converter/av1-converter.js \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ffmpeg-full ]}
    '';
  };
in
{
  environment.systemPackages = [
    av1-converter
    pkgs.ffmpeg-full
  ];
}
