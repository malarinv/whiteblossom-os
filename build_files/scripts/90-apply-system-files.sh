#!/usr/bin/env bash

set -eoux pipefail

copy_system_layer() {
  local src="$1"

  if [ ! -d "${src}" ]; then
    echo "System layer ${src} not found; skipping"
    return
  fi

  if find "${src}" -mindepth 1 -print -quit | grep -q .; then
    echo "Copying system files from ${src}"
    cp -a "${src}/." /
  else
    echo "No files to copy from ${src}; skipping"
  fi
}

copy_system_layer "${SYSTEM_DIR}/shared"
copy_system_layer "${SYSTEM_DIR}/gnome"
copy_system_layer "${SYSTEM_DIR}/kde"

