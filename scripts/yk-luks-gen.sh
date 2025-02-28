#!/usr/bin/env bash

set -euo pipefail

function usage {
cat >&2 <<EOF
Usage: yk-luks-gen [OPTIONS]

Generate key to unlock a LUKS partition with Yubikey

Options:

  -c, --storage=file       Path of the salt and iterations config
  -f, --file=file          Path of the generrated luks passphrase
  -p, --passphrase         Prompt for 2FA passphrase
  -s, --slot=number        Which slot on the YubiKey to challenge.
  -h, --help               Show this help
EOF
}

# Get CLI options
opts=$(getopt --options "c:f:ps:h" --long "storage:,file:,passphrase,slot:,help" -- "$@")

# Inspect CLI options
eval set -- "$opts"
while true; do
  case $1 in
    -c|--storage)
      STORAGE=$2
      shift 2
    ;;
    -f|--file)
      FILE=$2
      shift 2
    ;;
    -p|--passphrase)
      PROMPT_PHRASE=
      shift
    ;;
    -s|--slot)
      SLOT=$2
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

# Set system constants
SALT_LENGTH=16 # Passphrase salt length 16 bit
KEY_LENGTH=64 # Luks passphrase length 512 bit (64 * 8)
ITERATIONS=1000000 # Hash iterations

# Set defaults from specified options
: ${STORAGE:=/tmp/salt.conf}
: ${FILE:=/tmp/luks.key}
: ${SLOT:=1}

# Prompt for the passphrase
USER_PASSPHRASE=
if [[ "${PROMPT_PHRASE+DEFINED}" ]]; then
  read -s -p "Passphrase: " PASSPHRASE01
  echo
  read -s -p "Repeat Passphrase: " PASSPHRASE02
  echo
  if [ "$PASSPHRASE01" = "$PASSPHRASE02" ]; then
    USER_PASSPHRASE=$PASSPHRASE01
  else
   echo "Passphrase not match!"
   exit 1
  fi
fi

# Generate random salt
SALT="$(dd if=/dev/random bs=1 count=$SALT_LENGTH 2>/dev/null | rbtohex)"

# Use salt as yubikey challenge
CHALLENGE=$(echo -n $SALT | openssl dgst -binary -sha512 | rbtohex)

# Get yubikey response
RESPONSE=$(ykchalresp -$SLOT -N -x $CHALLENGE)

# Calculate LUKS key by concatenate user passphrase and yubikey response
echo "$USER_PASSPHRASE" | pbkdf2-sha512 $KEY_LENGTH $ITERATIONS $RESPONSE > $FILE

echo "LUKS passphrase generated in $FILE"

# Then Store salt parameters for luks key

echo -ne "$SALT\n$ITERATIONS" > $STORAGE

echo "LUKS salt parameters stored in $STORAGE"
