{
  description = "Lean Compiler Backend: a small native backend written in Lean 4";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
      environment = system:
        let
          pkgs = import nixpkgs { inherit system; };
          # Official release archives, also used by Concrete. See docs/UPSTREAM.md.
          assets = {
            aarch64-darwin = { name = "darwin_aarch64"; sha256 = "65f22a4f047738ec742667b3247e836a86ebf06eabc12655c3dee00637e37866"; };
            x86_64-darwin = { name = "darwin"; sha256 = "c2fee70250444e46c1106a27bddfef948d1e563eef431eaac05bb946b2f73d3a"; };
            aarch64-linux = { name = "linux_aarch64"; sha256 = "fdb974c2cdb4627e090d5d4007b913e09d13c4868720fb5594e22808b3de9e37"; };
            x86_64-linux = { name = "linux"; sha256 = "47bf4bbd78f70c2e9670598ab7124d92b6efb7330ff33e5fbb4030f6fd72e4e4"; };
          };
          asset = assets.${system};
          lean = pkgs.stdenv.mkDerivation {
            pname = "lcb-lean";
            version = "4.34.1";
            src = pkgs.fetchurl {
              url = "https://github.com/leanprover/lean4/releases/download/v4.34.1/lean-4.34.1-${asset.name}.tar.zst";
              inherit (asset) sha256;
            };
            nativeBuildInputs = [ pkgs.zstd ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
            buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];
            autoPatchelfIgnoreMissingDeps = true;
            dontConfigure = true;
            dontBuild = true;
            dontStrip = true;
            dontFixup = pkgs.stdenv.isDarwin;
            unpackPhase = ''tar --zstd -xf "$src"'';
            installPhase = ''mkdir -p "$out"; cp -R lean-4.34.1-${asset.name}/. "$out/"'';
          };
          # Lean's archive also ships a private clang without general C headers.
          # Put the Nix C wrapper first, and bind test tools by absolute paths.
          tools = [ pkgs.clang pkgs.llvmPackages.llvm lean pkgs.python3 pkgs.gnumake pkgs.coreutils pkgs.bash ];
          settings = {
            CC = "${pkgs.clang}/bin/clang";
            NM = "${pkgs.llvmPackages.llvm}/bin/llvm-nm";
            LCB_CC = "${pkgs.clang}/bin/clang";
            LCB_NM = "${pkgs.llvmPackages.llvm}/bin/llvm-nm";
            # Lake honors this override. The bundled Linux linker otherwise
            # produces ELF interpreters outside the Nix closure.
            LEAN_CC = "${pkgs.clang}/bin/clang";
          } // pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin { MACOSX_DEPLOYMENT_TARGET = "15.0"; };
        in { inherit pkgs lean tools settings; };
    in {
      packages = eachSystem (system:
        let e = environment system; in rec {
          default = lcb;
          lcb = e.pkgs.stdenv.mkDerivation (e.settings // {
            pname = "lean-compiler-backend";
            version = "0.1.0";
            src = e.pkgs.lib.cleanSourceWith {
              src = ./.;
              filter = path: type:
                !(builtins.elem (baseNameOf path) [ ".git" ".lake" ".build" "result" "__pycache__" ]);
            };
            nativeBuildInputs = e.tools;
            dontConfigure = true;
            buildPhase = ''
              runHook preBuild
              export HOME="$TMPDIR/lcb-home"
              mkdir -p "$HOME"
              lake build lcb lcb-tests
              runHook postBuild
            '';
            doCheck = true;
            checkPhase = ''
              runHook preCheck
              bash scripts/check.sh ${e.pkgs.lib.optionalString (system == "aarch64-darwin") "--require-native"}
              runHook postCheck
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/bin" "$out/share/lean-compiler-backend"
              cp .lake/build/bin/lcb "$out/bin/"
              cp -R LICENSE LICENSES README.md ROADMAP.md CHANGELOG.md port-status.json compiler-build.json docs upstream-lock.json third_party tests "$out/share/lean-compiler-backend/"
              runHook postInstall
            '';
            # Lean's official macOS runtime must remain intact; Linux fixups keep
            # the resulting compiler usable from its Nix closure.
            dontStrip = true;
            dontPatchShebangs = true; # retained upstream snapshots stay byte-identical
            meta = {
              description = "QBE-inspired native compiler backend written in Lean 4";
              license = [ e.pkgs.lib.licenses.mit e.pkgs.lib.licenses.asl20 ];
              platforms = systems;
              mainProgram = "lcb";
            };
          });
        });
      checks = eachSystem (system: { backend = self.packages.${system}.lcb; });
      apps = eachSystem (system: {
        default = { type = "app"; program = "${self.packages.${system}.lcb}/bin/lcb"; };
      });
      devShells = eachSystem (system:
        let e = environment system; in {
          default = e.pkgs.mkShell (e.settings // { packages = e.tools ++ [ e.pkgs.git ]; });
        });
    };
}
