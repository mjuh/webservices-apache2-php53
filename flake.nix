{
  description = "";

  nixConfig = {
    substituters = [ "https://cache.nixos.intr/" ];
    trustedPublicKeys = [ "cache.nixos.intr:6VD7bofl5zZFTEwsIDsUypprsgl7r9I+7OGY4WsubFA=" ];
  };

  inputs = {
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    flake-utils.url = "github:numtide/flake-utils";
    majordomo.url = "git+https://gitlab.intr/_ci/nixpkgs";
  };

  outputs = { self, flake-utils, nixpkgs, majordomo, ... } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: {
      devShell = with nixpkgs.legacyPackages."${system}"; mkShell {
        buildInputs = [ nixUnstable ];
        shellHook = ''
          . ${nixUnstable}/share/bash-completion/completions/nix
          export LANG=C
        '';
      };
    })
    // (let
      system = "x86_64-linux";
    in
      {
        packages.${system} = {
          container = import ./default.nix { nixpkgs = majordomo.outputs.nixpkgs; };
          deploy = majordomo.outputs.deploy { tag = "webservices/apache2-php53"; };
        };

        defaultPackage.${system} = self.packages.${system}.container;
      });
}
