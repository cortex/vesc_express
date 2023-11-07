{
  description = "Lindboard Firmware";
  inputs = {
    nixpkgs-esp-dev.url = "github:mirrexagon/nixpkgs-esp-dev";
  };
  outputs = { self, nixpkgs-esp-dev, nixpkgs, flake-utils }: 
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { 
        inherit system; 
        overlays = [ (import "${nixpkgs-esp-dev}/overlay.nix") ]; 
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.esp-idf-full
        ];
      };
    };
}
