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

  diff-highlight = with pkgs; stdenv.mkDerivation rec {
    name = "diff-highlight";
    version = "2.36.1";
    dontUnpack = true;
    src1 = fetchurl {
      url = "https://raw.githubusercontent.com/git/git/v${version}/contrib/diff-highlight/DiffHighlight.pm";
      sha256 = "0gg8vg426mnjcx1k1y6ihr6bj1sc6vqg0irsgn1gicpmk2xx1q0d";
    };
    src2 = fetchurl {
      url = "https://raw.githubusercontent.com/git/git/v${version}/contrib/diff-highlight/diff-highlight.perl";
      sha256 = "187f95klx2s6qhgr0qj1m9y7khyf9b722y598fwdgw701bpg5sjx";
    };
    installPhase = ''
      mkdir -p $out/bin
      echo "#!${perl}/bin/perl" > $out/bin/diff-highlight
      cat $src1 >> $out/bin/diff-highlight
      cat $src2 >> $out/bin/diff-highlight
      chmod +x $out/bin/diff-highlight
    '';
  };

  k8sdiff = pkgs.writeShellScriptBin "k8sdiff" ''
    diff -u -N --color=always "$@" | ${diff-highlight}/bin/diff-highlight | sed -E 's/(\/[a-zA-Z0-9_-]+)+\/([A-Z]*)-[0-9]*\/([A-Za-z0-9.-]+).*$/\2\t\3/'
  '';

  kapply = pkgs.writeShellScriptBin "kapply" ''
    set -e
    set -o pipefail
    target="$1"
    shift
    context="$(cd "$target"; git rev-parse --show-prefix | cut -d / -f1)"
    namespace="$(cd "$target"; git rev-parse --show-prefix | cut -d / -f2)"
    manifests="$(mktemp)"
    kustomize build "$target" > "$manifests"
    kubectl --context "$context" diff -f "$manifests" "$@" || echo $?
    while true; do
        read -p "Apply to context $context? [y/n] " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    kubectl --context "$context" apply -f "$manifests" "$@"
    current_context="$(kubectl config current-context)"
    current_namespace="$(kubectl config get-contexts "$current_context" | grep "$current_context" | awk '{ print $5 }')"
    if [ "$current_context" == "$context" ] && [ "$current_namespace" == "$namespace" ]; then
      exit
    fi
    read -p "Set context '$current_context'->'$context' and namespace '$current_namespace'->'$namespace'? [y/N] " yn
    case $yn in
        [Yy]* )
          kubectl config use-context "$context"
          kubectl config set-context --current --namespace "$namespace";;
        [Nn]* ) exit;;
        * ) exit;;
    esac
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
    version = "0.0.21";
    src = fetchurl {
      url = "https://github.com/jrpedrianes/kubecolor/releases/download/v${version}/kubecolor_${version}_Linux_x86_64.tar.gz";
      sha256 = "03qf4a29nffjkrhiskkchx94xd4k18carcq8jp1wkvz8a9z9yb4z";
    };
    sourceRoot = ".";
    installPhase = ''
      mkdir -p $out/bin
      cp kubecolor $out/bin/kubecolor
      chmod +x $out/bin/kubecolor
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
  KUBECTL_EXTERNAL_DIFF = "${k8sdiff}/bin/k8sdiff";
  STUVUS_INFRA_REPO = toString ../.;

  shellHook = ''
    ${if !inPlaybook then "if [ -f .nix-shell-hook ]; then source .nix-shell-hook; fi" else ""}
  '';
}
