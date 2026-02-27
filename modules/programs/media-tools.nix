{ pkgs, ... }:

let
  av1-converter = pkgs.stdenv.mkDerivation {
    pname = "av1-converter";
    version = "1.0.0";

    # We use the pre-bundled JS file from the dist directory
    src = ../../scripts/av1-converter/dist;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    dontBuild = true;

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
