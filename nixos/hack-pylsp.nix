{
  stdenv,
  python3,
  nodejs,
  writeScriptBin,
  js-beautify,
  uglify-js,
}:
let
  py = python3.withPackages (
    ps: with ps; [
      tree-sitter-language-pack
    ]
  );
in
stdenv.mkDerivation {
  name = "hack-pylsp";
  buildInputs = [
    py
    nodejs
    js-beautify
    uglify-js
  ];
  src = writeScriptBin "hack-pylsp" ''
    #!${stdenv.shell}
    export PATH=${nodejs}/bin:$PATH
    export PATH=${js-beautify}/bin:$PATH
    export PATH=${uglify-js}/bin:$PATH
    exec ${py}/bin/python3 ${./private/hack-pylsp.py} $@
  '';
  installPhase = ''
    cp -r $src/ $out
  '';
}
