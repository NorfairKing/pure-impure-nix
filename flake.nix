{
  description = "pure-impure-nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-23.05";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs =
    { self
    , nixpkgs
    , pre-commit-hooks
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # This is where the (evil?) magic happens.
      makePureImpure = drv: drv.overrideAttrs (old:
        let
          magicString = builtins.unsafeDiscardStringContext (builtins.substring 0 12 (baseNameOf drv.drvPath));
          outputHashAlgo = "sha256";
          outputHash = builtins.hashString outputHashAlgo magicString;
        in
        {
          preferHashedMirrors = false;
          inherit outputHashAlgo;
          inherit outputHash;
          buildCommand = ''
            ${old.buildCommand or ""}
            rm -rf $out
            echo -n "${magicString}" > $out
          '';
        });

      testDerivation = pkgs.stdenv.mkDerivation {
        name = "pure-impure-test";
        dontUnpack = true;
        buildInputs = [ pkgs.cacert pkgs.curl ];
        buildCommand = ''
          curl https://cs-syd.eu > $out
        '';
      };
    in
    {
      checks.${system} = {
        test = makePureImpure testDerivation;
        pre-commit = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
          };
        };
      };
      lib = { inherit makePureImpure; };
      devShells.${system}.default = pkgs.mkShell {
        name = "pure-impure-nix-shell";
        shellHook = self.checks.${system}.pre-commit.shellHook;
      };
    };
}
