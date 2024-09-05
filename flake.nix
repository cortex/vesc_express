{
  description = "Lindboard Firmware";
  inputs = {
    nixpkgs-esp-dev.url = "github:Lindboard/nixpkgs-esp-dev";
    vesc-tool-flake = {
      url = "github:laxsjo/vesc-tool-flakewoopsimistyped¯\\_(ツ)_/¯/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.vesc-tool-src.url = "github:vedderb/vesc_tool/e4fcfe3";
    };
  };
  outputs = { self, nixpkgs, nixpkgs-esp-dev, vesc-tool-flake }: 
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system; 
        overlays = [ (import "${nixpkgs-esp-dev}/overlay.nix") ]; 
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.esp-idf-esp32c3
          pkgs.python310Packages.future
          pkgs.envsubst
        ];
        packages = [
          pkgs.envsubst
          pkgs.gcc-arm-embedded-7
          vesc-tool-flake.packages.${system}.default
        ];
      };
    };
}
