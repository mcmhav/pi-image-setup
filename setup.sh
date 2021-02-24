#!/usr/bin/env bash

RASPBIAN="RASPBIAN"
ARCH="ARCH"

DISK_NUM=""
DISK=""
TMP_FOLDER="tmp"
TMP_CONFIG_DIR="$TMP_FOLDER/config"
OS="$RASPBIAN"
PI_HOSTNAME="raspberrypi"
IMAGE_FILE=""
IMAGE_FILE_PATH=""
PASSWORDS=()
SSIDS=()

display_help="
$(basename "$0") [-h] [-r] [-d] -- starts simple proxy

where:
  -ru, --reverse-url    sets reverse url
  -p, --port            sets proxy port
  -h, --help            show this help text
"

read_config() {
  loggit "Reading config"
  if [ -f "./config" ]; then
    source "./config"
  else
    loggit "No config found, will be relying on input options"
  fi
}

set_inputs() {
  while [ "$1" != "" ]; do
    case $1 in
    -d | --disk)
      shift
      if test $# -gt 0; then
        DISK_NUM=$1
        DISK="disk$DISK_NUM"
        IDENTIFIER="s2"
        DISK_IDENTIFIER="disk$DISK_NUM$IDENTIFIER"
      else
        loggit "no disk"
        exit 1
      fi
      ;;
    -os | --os)
      shift
      if test $# -gt 0; then
        OS=$1
      else
        loggit "no os"
        exit 1
      fi
      ;;
    -p | --password)
      shift
      if test $# -gt 0; then
        PASSWORDS+=("$1")
      else
        loggit "no pass specified"
        exit 1
      fi
      ;;
    -s | --ssid)
      shift
      if test $# -gt 0; then
        SSIDS+=("$1")
      else
        loggit "no ssid specified"
        exit 1
      fi
      ;;
    -h | --help)
      echo "$display_help"
      exit
      ;;
    -c | --clean)
      rm -r $TMP_FOLDER
      ;;
    *)
      loggit "Time plz"
      ;;
    esac
    shift
  done

  if [ -z "$DISK" ] || [ -z "$DISK_NUM" ]; then
    loggit "No disk!"
    loggit "run 'diskutil list' to find disk and disknumber"
    exit
  fi

  if [ ${#PASSWORDS[@]} != ${#SSIDS[@]} ]; then
    loggit "Not same amount of ssids and passwords!"
    exit
  fi
}

get_image() {
  echo "=== Fetching image"
  if [ "$OS" == "$RASPBIAN" ]; then
    IMAGE_FILE=raspbian_lite_latest.zip
    IMAGE_URL=https://downloads.raspberrypi.org/raspbian_lite_latest
  elif [ "$OS" == "$ARCH" ]; then
    IMAGE_FILE=ArchLinuxARM-rpi-latest.tar.gz
    IMAGE_URL=http://os.archlinuxarm.org/os/"$IMAGE_FILE"
  else
    exit
  fi
  IMAGE_FILE_PATH="$TMP_FOLDER"/"$IMAGE_FILE"

  mkdir -p $TMP_FOLDER

  if [ ! -f "$IMAGE_FILE_PATH" ]; then
    curl -L -o $IMAGE_FILE_PATH $IMAGE_URL
  fi
}

ready_image() {
  echo "=== Getting image ready"
  if [ "$OS" == "$RASPBIAN" ]; then
    if [ ! -f "$TMP_FOLDER/image.img" ]; then
      unzip -n "$IMAGE_FILE_PATH" -d "$TMP_FOLDER"
      mv "$TMP_FOLDER"/*.img "image.img"
      mv image.img "$TMP_FOLDER/image.img"
    fi
  elif [ "$OS" == "$ARCH" ]; then
    echo "TODO: Nothing to do?"
  else
    exit
  fi
}

ready_disk() {
  echo "=== Getting disk ready"
  if [ "$OS" == "$RASPBIAN" ]; then
    DISK_NAME="RASPBIAN"
    diskutil eraseDisk FAT32 "$DISK_NAME" "/dev/$DISK"

    diskutil unmountDisk "/dev/$DISK"
  elif [ "$OS" == "$ARCH" ]; then
    DISK_NAME="ARCHDISK"
    diskutil unmountDisk "/dev/$DISK"

    diskutil eraseDisk FAT32 "$DISK_NAME" "/dev/$DISK"
  else
    exit
  fi
}

move_img_to_disk() {
  echo "=== Moving image to disk"
  if [ "$OS" == "$RASPBIAN" ]; then
    sudo dd bs=1m if="$TMP_FOLDER"/image.img of=/dev/rdisk"$DISK_NUM" conv=sync
  elif [ "$OS" == "$ARCH" ]; then
    echo "TODO"
  else
    exit
  fi
}

create_config_dir() {
  mkdir -p "$TMP_CONFIG_DIR"
}

setup_wifi() {
  echo "=== Setting up wifi"
  if [ -n "${PASSWORDS[*]}" ]; then
    rm -f "$TMP_CONFIG_DIR/wpa_supplicant.conf"
    cat <<EOF >>"$TMP_CONFIG_DIR/wpa_supplicant.conf"
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=NO

EOF
    NETWORKS_LEN=${#PASSWORDS[@]}
    for ((i = 0; i < "${NETWORKS_LEN}"; i++)); do
      cat <<EOF >>"$TMP_CONFIG_DIR/wpa_supplicant.conf"
network={
ssid="${SSIDS[$i]}"
psk="${PASSWORDS[$i]}"
}

EOF
    done
  fi

}

setup_ssh() {
  echo "=== Setting up ssh"
  touch "$TMP_CONFIG_DIR/ssh"
}

setup_secrets() {
  echo "=== Setting up secrets"
  cp "$HOME/r/s/sys-setup/bash/bashrc/.secrets" "$TMP_CONFIG_DIR/secrets"
  chmod +x "$TMP_CONFIG_DIR/secrets"
}

setup_script() {
  if [ "$OS" == "$RASPBIAN" ]; then
    loggit "Setting up setupfile"
    cp "raspbian_setup.sh" "$TMP_CONFIG_DIR"
    sed -i "" "s/<<HOSTNAME>>/$PI_HOSTNAME/" "$TMP_CONFIG_DIR/raspbian_setup.sh"
  fi
}

move_config_to_disk() {
  echo "=== Moving configs"
  sleep 3
  diskutil mountDisk "/dev/$DISK"
  cp "$TMP_CONFIG_DIR/"* "/Volumes/boot/"
}

unmount_disk() {
  loggit "Unmounting disk"
  sleep 3
  diskutil unmountDisk "/dev/$DISK"
}

setup_pi_disk() {
  read_config

  set_inputs "$@"

  get_image

  ready_image

  ready_disk

  move_img_to_disk

  create_config_dir
  setup_wifi
  setup_ssh
  setup_secrets
  setup_script
  move_config_to_disk
  unmount_disk
}

setup_pi_disk "$@"
