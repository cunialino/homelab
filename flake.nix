{
  description = "Zola build environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      zola-builder = pkgs.writeShellScriptBin "zola-builder" ''
        ${pkgs.zola}/bin/zola -r docs build
      '';
    in
    {
      apps.${system}.default = {
        type = "app";
        program = "${zola-builder}/bin/zola-builder";
      };
    };
}
