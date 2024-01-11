let
  pkgs = import <nixpkgs> {};
in
pkgs.stdenv.mkDerivation rec {
  pname = "vesc-tool";
  version = "git";

  meta = with pkgs.lib; {
    description = "VESC Tool";
  };

  src = pkgs.fetchFromGitHub {
    owner = "vedderb";
    repo = "vesc_tool";
    rev = "master";
    hash = "sha256-qxncEJ//3zkqAuT2w9Mewh42EONLgIFy4QyZUJg2NHs=";
  };
  patches = [
    ./res_fw.patch
  ];
  configurePhase = ''
    qmake -config release "CONFIG += release_lin build_original"
  '';
  buildPhase = ''
    make -j8
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp build/lin/vesc_tool_6.05 $out/bin
  '';

  buildInputs = [ pkgs.libsForQt5.qtbase ];
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.libsForQt5.qtbase
    pkgs.libsForQt5.qtquickcontrols2
    pkgs.libsForQt5.qtgamepad
    pkgs.libsForQt5.qtconnectivity
    pkgs.libsForQt5.qtpositioning
    pkgs.libsForQt5.qtserialport
    pkgs.libsForQt5.qtgraphicaleffects
    pkgs.libsForQt5.wrapQtAppsHook
  ];
}
