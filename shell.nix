{ pkgs ? import <nixpkgs> {}, inPlaybook ? false }:

let
  # Pin Ansible 2.10.0 from NixOS 20.09
  ansible = (import (builtins.fetchTarball {
    name = "nixos-20.09-2020-10-03";
    url = "https://github.com/nixos/nixpkgs/archive/0cfe5377e8993052f9b0dd56d058f8008af45bd9.tar.gz";
    sha256 = "0i3ybddi2mrlaz3di3svdpgy93zwmdglpywih4s9rd3wj865gzn1";
  }) {}).ansible;

  colordiff = pkgs.writeShellScriptBin "colordiff" ''
    diff -u -N --color=always "$@"
    # Exit status of diff is 0 if inputs are the same, 1 if different, 2 if trouble.
    # We only want to exit with an error if there's trouble, not if they are different.
    if [ $? -eq 2 ]; then
        exit 2
    fi
    exit 0
  '';

  kapply = pkgs.writeShellScriptBin "kapply" ''
    set -e
    set -o pipefail
    target="$1"
    shift
    manifests="$(mktemp)"
    kustomize build "$target" > "$manifests"
    kubectl diff -f "$manifests" "$@"
    while true; do
        read -p "Apply? [y/n] " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    kustomize build "$target" | kubectl apply -f "$manifests" "$@"
  '';

  virtctl = with pkgs; stdenv.mkDerivation rec {
    pname = "virtctl";
    version = "0.33.0";
    src = pkgs.fetchurl {
      url = "https://github.com/kubevirt/kubevirt/releases/download/v${version}/virtctl-v${version}-linux-x86_64";
      sha256 = "1qv7m6njm0v6qs2fz8z756v95k1h1d5r7pmzaasq32khm48rg5hh";
    };
    dontUnpack = true;
    nativeBuildInputs = [
      autoPatchelfHook
    ];
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/virtctl
      chmod +x $out/bin/virtctl
    '';
  };

  minio-warp = with pkgs; stdenv.mkDerivation rec {
    pname = "warp";
    version = "0.3.28";
    src = fetchurl {
      url = "https://github.com/minio/warp/releases/download/v${version}/warp_${version}_Linux_x86_64.tar.gz";
      sha256 = "0gjqz21lyykf6ia9wa4krn1nsg1y41zah6m3c1lzy1sb44f8k6rm";
    };
    sourceRoot = ".";
    installPhase = ''
      mkdir -p $out/bin
      cp warp $out/bin/warp
    '';
  };

  kubectl-minio = with pkgs; stdenv.mkDerivation rec {
    pname = "kubectl-minio";
    version = "3.0.29";
    src = fetchurl {
      url = "https://github.com/minio/operator/releases/download/v${version}/kubectl-minio_${version}_linux_amd64";
      sha256 = "0mxkicrkbxly60yxm6xm4r3xrcn6bjyfyzw3qjf04s14g08slidw";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/kubectl-minio
      chmod +x $out/bin/kubectl-minio
    '';
  };

  kubelogin = with pkgs; stdenv.mkDerivation rec {
    pname = "kubelogin";
    version = "1.22.1";
    src = fetchurl {
      url = "https://github.com/int128/kubelogin/releases/download/v${version}/kubelogin_linux_amd64.zip";
      sha256 = "09k7pi7251xn1nfsw77bhf6dx2263l3d3n3bv715i3qp6mjqmg6z";
    };
    nativeBuildInputs = [
      unzip
    ];
    sourceRoot = ".";
    installPhase = ''
      mkdir -p $out/bin
      cp kubelogin $out/bin/kubectl-oidc_login
    '';
  };

  velero = with pkgs; stdenv.mkDerivation rec {
    pname = "velero";
    version = "1.5.2";
    src = fetchurl {
      url = "https://github.com/vmware-tanzu/velero/releases/download/v1.5.2/velero-v1.5.2-linux-amd64.tar.gz";
      sha256 = "0kx209q1b9z85brq9w7v0aafkpa292djzhpn1xjmfw8ww2xnxz1d";
    };
    installPhase = ''
      mkdir -p $out/bin
      cp velero $out/bin/velero
    '';
  };

  kubectl-ns = pkgs.writeShellScriptBin "kubectl-ns" ''
    kubectl config set-context --current --namespace "$@"
  '';

  # You need to run `source kubectl-comp`
  kubectl-comp = pkgs.writeShellScriptBin "kubectl-comp" ''
      source <(kubectl completion bash)
  '';
in

# stdenvNoCC because we don't need a C-compiler during build or
# when using the nix-shell
pkgs.stdenvNoCC.mkDerivation {
  name = "stuvus_config-shell";

  nativeBuildInputs = with pkgs; [
    ansible
    bashInteractive
    hugo
    jq
    kapply
    kubectl
    kubectl-comp
    kubectl-minio
    kubectl-ns
    kubelogin
    kubernetes-helm
    kustomize
    minio-client
    minio-warp
    postgresql_12
    (python3.withPackages(ps: with ps; [
      autopep8
      jmespath
      pylint
      pyyaml
    ]))
    sshpass
    sshuttle
    stern
    tigervnc
    velero
    virtctl
    yq
  ];

  shellHook = ''
    export IN_STUVUS_NIX_SHELL=1
    export KUBECONFIG=./kubeconfig
    export KUBECTL_EXTERNAL_DIFF="${colordiff}/bin/colordiff"
    ${if !inPlaybook then "if [ -f .nix-shell-hook ]; then source .nix-shell-hook; fi" else ""}
  '';
}
