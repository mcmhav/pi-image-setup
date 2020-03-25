#!/usr/bin/env bash

RASPBIAN="RASPBIAN"
ARCH="ARCH"

DISK_NUM=""
DISK=""
TMP_FOLDER="tmp"
OS="$RASPBIAN"
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

set_inputs() {
  while [ "$1" != "" ]; do
    case $1 in
    -d | --disk)
      shift
      if test $# -gt 0; then
        DISK_NUM=$1
        DISK="disk$DISK_NUM"
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

setup_wifi() {
  echo "=== Setting up wifi"
  if [ -n "${PASSWORDS[*]}" ]; then
    rm -f "$TMP_FOLDER/wpa_supplicant.conf"
    cat <<EOF >>"$TMP_FOLDER/wpa_supplicant.conf"
country=NO
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
tls_disable_tlsv1_0=1
tls_disable_tlsv1_1=1

EOF
    NETWORKS_LEN=${#PASSWORDS[@]}
    for ((i = 0; i < "${NETWORKS_LEN}"; i++)); do
      echo "${PASSWORDS[$i]}"
      cat <<EOF >>"$TMP_FOLDER/wpa_supplicant.conf"
network={
        ssid="${SSIDS[$i]}"
        psk="${PASSWORDS[$i]}"
        key_mgmt=WPA-PSK
}

EOF
    done
  fi

}

setup_ssh() {
  echo "=== Setting up ssh"
  touch "$TMP_FOLDER/ssh"
}

setup_pi_disk() {
  set_inputs "$@"

  get_image

  ready_image

  ready_disk

  move_img_to_disk

  setup_wifi

  setup_ssh
}

setup_pi_disk "$@"
