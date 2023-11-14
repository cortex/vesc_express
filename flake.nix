{
  description = "Lindboard Firmware";
  inputs = {
    nixpkgs-esp-dev.url = "github:mirrexagon/nixpkgs-esp-dev";
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
          (pkgs.esp-idf-esp32c3.override {
            rev = "v5.0.2";
            sha256 = "sha256-dlmtTjoz4qQdFG229v9bIHKpYBzjM44fv+XhdDBu2Os=";
          })
          pkgs.python310Packages.future
          pkgs.envsubst
        ];
        packages = [
          pkgs.envsubst
          pkgs.gcc-arm-embedded
        ];
      };
    };
}
