#!/usr/bin/env bash

set -eoux pipefail

if [ -f "${DESKTOP_DIR}/install-kde-packages.sh" ]; then
  bash "${DESKTOP_DIR}/install-kde-packages.sh"
else
  echo "Skipping KDE package installation; script not found at ${DESKTOP_DIR}/install-kde-packages.sh"
fi

