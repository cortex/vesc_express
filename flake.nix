{
  description = "Lindboard Firmware";
  inputs = {
    nixpkgs-esp-dev.url = "github:Lindboard/nixpkgs-esp-dev";
  };
  outputs = { self, nixpkgs-esp-dev, nixpkgs}: 
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { 
        inherit system; 
        overlays = [ (import "${nixpkgs-esp-dev}/overlay.nix") ]; 
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          /*pkgs.esp-idf-esp32c3*/
          (pkgs.esp-idf-esp32c3.override {
            rev = "v5.2.2";
            sha256 = "sha256-I4YxxSGdQT8twkoFx3zmZhyLTSagmeLD2pygVfY/pEk=";
          })
          pkgs.python310Packages.future
          pkgs.envsubst
        ];
        packages = [
          pkgs.envsubst
          pkgs.gcc-arm-embedded-7
        ];
      };
    };
}
