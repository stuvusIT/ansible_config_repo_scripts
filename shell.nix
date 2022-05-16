{ pkgs ? import <nixpkgs> {}, inPlaybook ? false }:

let
  calicoctl = with pkgs; stdenv.mkDerivation rec {
    pname = "calicoctl";
    version = "3.18.4";
    src = fetchurl {
      url = "https://github.com/projectcalico/calicoctl/releases/download/v${version}/calicoctl-linux-amd64";
      sha256 = "0yjlkgf4l8argmgs9awj2h61nljrw1ya1m2fgnanqivqjidlmrva";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/calicoctl
      chmod +x $out/bin/calicoctl
    '';
  };

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
    kubectl apply -f "$manifests" "$@"
  '';

  virtctl = with pkgs; stdenv.mkDerivation rec {
    pname = "virtctl";
    version = "0.52.0";
    src = pkgs.fetchurl {
      url = "https://github.com/kubevirt/kubevirt/releases/download/v${version}/virtctl-v${version}-linux-amd64";
      sha256 = "09kgxvfzn9y2s6px87p4d42p5l6qc8mk0wfn9f4a8pgi0b99ln1c";
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

  kubecolor = with pkgs; stdenv.mkDerivation rec {
    pname = "kubecolor";
    version = "0.0.20";
    src = fetchurl {
      url = "https://github.com/dty1er/kubecolor/releases/download/v${version}/kubecolor_${version}_Linux_x86_64.tar.gz";
      sha256 = "1hykqdq904z1l96ah7acnjh7g43lkz2lf3wm0x4h0ilq5kmd0gp5";
    };
    sourceRoot = ".";
    installPhase = ''
      mkdir -p $out/bin
      cp kubecolor $out/bin/kubecolor
      chmod +x $out/bin/kubecolor
    '';
  };

  velero = with pkgs; stdenv.mkDerivation rec {
    pname = "velero";
    version = "1.6.0";
    src = fetchurl {
      url = "https://github.com/vmware-tanzu/velero/releases/download/v${version}/velero-v${version}-linux-amd64.tar.gz";
      sha256 = "1pbp27q0zmvhiwdj5wl7pgqrd281ybxsdgn0xmvn93gihvwn5g83";
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

  restic = with pkgs; stdenv.mkDerivation rec {
    pname = "restic";
    version = "0.12.0";
    src = fetchurl {
      url = "https://github.com/restic/restic/releases/download/v${version}/restic_${version}_linux_amd64.bz2";
      sha256 = "102biy5xh2yikq11zf9rw93yqw4wm0rgw2qz8r6sma2fhd9kvlb3";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      bzip2 -dk $src --stdout > $out/bin/restic
      chmod +x $out/bin/restic
    '';
  };

in

# stdenvNoCC because we don't need a C-compiler during build or
# when using the nix-shell
pkgs.stdenvNoCC.mkDerivation {
  name = "stuvus_config-shell";

  nativeBuildInputs = with pkgs; [
    ansible
    bashInteractive
    calicoctl
    gojsontoyaml
    hugo
    jq
    jsonnet
    jsonnet-bundler
    k9s
    kapply
    kubecolor
    kubectl
    kubectl-comp
    kubectl-ns
    kubelogin-oidc
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
    restic
    sshpass
    sshuttle
    stern
    tigervnc
    velero
    virtctl
    yq
  ];

  IN_STUVUS_NIX_SHELL = "1";
  KUBECONFIG = toString ../kubeconfig;
  KUBECTL_EXTERNAL_DIFF = "${colordiff}/bin/colordiff";
  STUVUS_INFRA_REPO = toString ../.;

  shellHook = ''
    ${if !inPlaybook then "if [ -f .nix-shell-hook ]; then source .nix-shell-hook; fi" else ""}
  '';
}
