{ pkgs ? import <nixpkgs> {}, inPlaybook ? false }:

let
  # Pin Ansible 2.10.0 from NixOS 20.09
  ansible = (import (builtins.fetchTarball {
    name = "nixos-20.09-2020-10-03";
    url = "https://github.com/nixos/nixpkgs/archive/0cfe5377e8993052f9b0dd56d058f8008af45bd9.tar.gz";
    sha256 = "0i3ybddi2mrlaz3di3svdpgy93zwmdglpywih4s9rd3wj865gzn1";
  }) {}).ansible;

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

  kubectl-minio = with pkgs; stdenv.mkDerivation rec {
    pname = "kubectl-minio";
    version = "3.0.29";
    src = pkgs.fetchurl {
      url = "https://github.com/minio/operator/releases/download/v${version}/kubectl-minio_${version}_linux_amd64";
      sha256 = "0mxkicrkbxly60yxm6xm4r3xrcn6bjyfyzw3qjf04s14g08slidw";
    };
    nativeBuildInputs = [
      autoPatchelfHook
    ];
    phases = [ "installPhase" "fixupPhase" ];
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/kubectl-minio
      chmod +x $out/bin/kubectl-minio
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
    kubectl-minio
    kubernetes-helm
    minio-client
    (python3.withPackages(ps: with ps; [
      autopep8
      jmespath
      pylint
      pyyaml
    ]))
    sshpass
    sshuttle
    tigervnc
    virtctl
  ];

  shellHook = ''
    export IN_STUVUS_NIX_SHELL=1
    export KUBECONFIG=./kubeconfig
    ${if !inPlaybook then "if [ -f .nix-shell-hook ]; then source .nix-shell-hook; fi" else ""}
  '';
}
