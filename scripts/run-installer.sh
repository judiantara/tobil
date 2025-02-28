#!/usr/bin/env bash

set -euo pipefail

function usage {
cat >&2 <<EOF
Usage: run-installer [OPTIONS]

Install NixOS for host according to flake

Options:

  -m, --machine=machine  Name of target machine, required
  -f, --flake=file       Path to nix installation flake, required
  -h, --help             Show this help
EOF
}

# Get CLI options
opts=$(getopt --options "m:f:h" --long "machine:,flake:,help" -- "$@")

# Inspect CLI options
eval set -- "$opts"
while true; do
  case $1 in
    -f|--flake)
      FLAKE_ROOT=$2
      shift 2
    ;;
    -m|--machine)
      TARGET_MACHINE=$2
      shift 2
    ;;
    -h|--help)
      usage
      exit 0
    ;;
    --)
      shift
      break
    ;;
    *)
      echo -e "Unhandled option '$1'"
      exit 2
    ;;
  esac
done

# sanity check
: ${TARGET_MACHINE:?"Missing -m parameter"}
: ${FLAKE_ROOT:?"Missing -f parameter"}

FLAKE_REPO=$FLAKE_ROOT#$TARGET_MACHINE
AGE_IDENTITY_KEY=/etc/ssh/ssh_host_ed25519_key
PERSIST_FILES=$FLAKE_ROOT/persist/$TARGET_MACHINE/$TARGET_MACHINE.tar.age

SALT="/tmp/salt.conf"
KEY="/tmp/luks.key"

if [ ! -f $SALT ]; then
  echo "Generate luks key..."
  yk-luks-gen -c $SALT -f $KEY
  echo

  echo "Partitioning disk..."
  disko --mode zap_create_mount --flake $FLAKE_REPO
  echo
fi

echo "Install persisted files..."
mkdir -p /mnt/{boot,nix/persist,etc/{nixos,ssh},var/{lib,log},srv}
rage -d -i $AGE_IDENTITY_KEY $PERSIST_FILES | tar --no-same-owner -xvC /mnt/nix/persist
echo

if [ -f $SALT ]; then
  echo "Install luks salt..."
  cp /tmp/salt.conf /mnt/boot/
  echo
fi

# echo "Removing unused channel..."
# nix-channel --remove nixos
# echo

echo "Install NixOS..."
nixos-install --channel unstable --no-channel-copy --no-root-password --no-write-lock-file --flake $FLAKE_REPO --root /mnt --cores 0
