{
  stdenv,
  python3,
  nodejs,
  writeScriptBin,
  nodePackages
}:
let
  py = python3.withPackages (ps: with ps; [
    tree-sitter-language-pack
  ]);
in
stdenv.mkDerivation {
  name = "hack-pylsp";
  buildInputs = [
    py
    nodejs
    nodePackages.js-beautify
    nodePackages.uglify-js
  ];
  src = writeScriptBin "hack-pylsp" ''
    #!${stdenv.shell}
    export PATH=${nodejs}/bin:$PATH
    export PATH=${nodePackages.js-beautify}/bin:$PATH
    export PATH=${nodePackages.uglify-js}/bin:$PATH
    exec ${py}/bin/python3 ${./private/hack-pylsp.py} $@
  '';
  installPhase = ''
    cp -r $src/ $out
  '';
}
