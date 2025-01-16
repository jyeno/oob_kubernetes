{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    terraform   # cli tool needed
    cdrtools    # cli tool used by terraform to create an ISO file
    openssh
    ansible
    libxslt
    python311
    python311Packages.docker
    python311Packages.kubernetes
  ];
  shellHook = ''
    # Creates the ssh key used by this project if not exists
    mkdir -p keys
    [ -e keys/id_ed25519 ] || ssh-keygen -t ed25519 -f keys/id_ed25519
    # Creates pool directory if needed, currently using the ubuntu one directly
    mkdir -p pool/images/terraform-provider-libvirt-pool-ubuntu
  '';
}

