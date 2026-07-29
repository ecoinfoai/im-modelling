{
  description = "im-modelling — Quarto site for 감염미생물학 teaching material";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # nixpkgs' quarto builds against pandoc 3.7, but quarto 1.10 hard-fails on
      # anything but 3.8.3 ("Unknown option syntax-highlighting"), and nixpkgs
      # carries no 3.8. The upstream tarball vendors the toolchain it expects.
      quarto = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "quarto";
        version = "1.10.18";

        src = pkgs.fetchurl {
          url = "https://github.com/quarto-dev/quarto-cli/releases/download/v${finalAttrs.version}/quarto-${finalAttrs.version}-linux-amd64.tar.gz";
          hash = "sha256-r60HG1vSLALy0wBpV0MYnTZQ4FN6Uwc+ZUtjDP8rDHM=";
        };

        nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];

        installPhase = ''
          runHook preInstall
          mkdir -p $out/libexec/quarto
          cp -r . $out/libexec/quarto
          makeWrapper $out/libexec/quarto/bin/quarto $out/bin/quarto
          runHook postInstall
        '';

        meta = {
          description = "Scientific and technical publishing system (upstream build)";
          homepage = "https://quarto.org";
          license = pkgs.lib.licenses.mit;
          platforms = [ "x86_64-linux" ];
          mainProgram = "quarto";
        };
      });
    in
    {
      packages.${system} = {
        inherit quarto;
        default = quarto;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ quarto ];
      };
    };
}
