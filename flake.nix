{
  description = "Tobil the NixOS installer";

  inputs = {
    nixpkgs = {
      #url = "github:nixos/nixpkgs/nixos-unstable";
      url = "github:NixOS/nixpkgs/nixos-24.11";
    };
  };

  outputs = {self, nixpkgs, ... }@inputs: let
    system    = "x86_64-linux";
    pkgs      = import nixpkgs { inherit system; };
    
    pbkdf2-sha512 = pkgs.callPackage ./pbkdf2-sha512 { };
    
    rbtohex = pkgs.writeShellScriptBin
      "rbtohex"
     (builtins.readFile ./scripts/rbtohex.sh);

    hextorb = pkgs.writeShellScriptBin
      "hextorb"
     (builtins.readFile ./scripts/hextorb.sh);

    yk-luks-gen = pkgs.writeShellScriptBin 
     "yk-luks-gen" 
     (builtins.readFile ./scripts/yk-luks-gen.sh);

    run-installer = pkgs.writeShellScriptBin 
     "run-installer" 
     (builtins.readFile ./scripts/run-installer.sh);

  in {
    devShells.${system}.run-installer = pkgs.mkShell {
      packages = with pkgs; [
        disko
        cryptsetup
        openssl
        parted
        yubikey-personalization
        rage
        pbkdf2-sha512
        rbtohex
        hextorb
        yk-luks-gen
        run-installer
      ];
      shellHook = ''
      set -euo pipefail
      echo "Tobil the ultimate installer"
      if [[ "''${TARGET_MACHINE:?}" && "''${FLAKE_ROOT:?}" ]]; then
        echo "Install NixOS for host ''$TARGET_MACHINE Using nix flake: ''$FLAKE_ROOT"
        run-installer -m ''$TARGET_MACHINE -f ''$FLAKE_ROOT
        exit ''$?
      fi
      '';
    };
  };
}
