# Pure impure Nix

Allow nix derivations that need internet access to be built in pure nix as long as you don't need their output (only whether they succeed).

See the implementation of [`makePureImpure` in `flake.nix`](./flake.nix) for the full details.


Why is this useful?
Short answer: I'm not sure, but it can be helpful that we know it is possible.

Long(er) answer:

* Impure E2E tests in (evil?) CI
* (Evil?) telemetry about which nix derivations are built
* ...
