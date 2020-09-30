{ pkgs ? import <nixpkgs> {}, inPlaybook ? false }:

let
  virtctl = with pkgs; stdenv.mkDerivation rec {
    pname = "virtctl";
    version = "0.33.0";
    src = pkgs.fetchurl {
      url = "https://github.com/kubevirt/kubevirt/releases/download/v${version}/virtctl-v${version}-linux-x86_64";
      sha256 = "1qv7m6njm0v6qs2fz8z756v95k1h1d5r7pmzaasq32khm48rg5hh";
    };
    nativeBuildInputs = [
      autoPatchelfHook
    ];
    phases = [ "installPhase" "fixupPhase" ];
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/virtctl
      chmod +x $out/bin/virtctl
    '';
  };
in

# stdenvNoCC because we don't need a C-compiler during build or
# when using the nix-shell
pkgs.stdenvNoCC.mkDerivation {
  name = "stuvus_config-shell";

  nativeBuildInputs = with pkgs; [
    ansible
    kubectl
    kubernetes-helm
    (python3.withPackages(ps: with ps; [
      autopep8
      jmespath
      pylint
      pyyaml
    ]))
    sshpass
    tigervnc
    virtctl
  ];

  shellHook = ''
    export IN_STUVUS_NIX_SHELL=1
    export KUBECONFIG=./kubeconfig
    ${if !inPlaybook then "if [ -f .nix-shell-hook ]; then source .nix-shell-hook; fi" else ""}
  '';
}
