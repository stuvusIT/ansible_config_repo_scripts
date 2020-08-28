{ pkgs ? import <nixpkgs> {}, inPlaybook ? false }:

# stdenvNoCC because we don't need a C-compiler during build or
# when using the nix-shell
pkgs.stdenvNoCC.mkDerivation {
  name = "stuvus_config-shell";

  nativeBuildInputs = with pkgs; [
    ansible
    kubectl
    kubernetes-helm
    sshpass
    (python3.withPackages(ps: with ps; [
      autopep8
      jmespath
      pylint
      pyyaml
    ]))
  ];

  shellHook = ''
    export IN_STUVUS_NIX_SHELL=1
    export KUBECONFIG=./kubeconfig
    ${if !inPlaybook then "if [ -f .nix-shell-hook ]; then source .nix-shell-hook; fi" else ""}
  '';
}
