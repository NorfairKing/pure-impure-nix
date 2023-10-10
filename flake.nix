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

      # makePureImpure : Derivation -> Derivation
      #
      # This function turns a derivation that wants to access the internet (but
      # fails because it tries to do so) into one that is allowed to access the
      # internet but not produce any (useful) output.
      #
      # Note that this function (currently) only works for derivation produced
      # with `mkDerivation` using `buildCommand`. PR Welcome.
      #
      # 
      # This is where the (evil?) magic happens.
      #
      # Important to know:
      #
      # * Nix lets derivations access the internet as long as they specify the
      #   hash of the output. [citation needed]
      # 
      # * If you know the exact output of a derivation up front, you can
      #   (pre-)compute the hash.
      # 
      # * We can know the exact output of a derivation up front if we replace
      #   the actual output of a derivation by a magic string.
      #
      #
      # Here's the plan:
      #
      # 1. We choose a magic string based on the store hash of the derivation.
      # 2. We (pre-)compute the hash of this magic string in pure Nix.
      # 3. We set the output hash of the derivation to this hash.
      # 4. After 'building' the derivation, we remove the `$out` and replace it
      #    by the magic string.
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
