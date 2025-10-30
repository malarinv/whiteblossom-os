#!/usr/bin/env bash

set -eoux pipefail

if [ -f "${DESKTOP_DIR}/install-dx-tools.sh" ]; then
  bash "${DESKTOP_DIR}/install-dx-tools.sh"
else
  echo "Skipping DX tools installation; script not found at ${DESKTOP_DIR}/install-dx-tools.sh"
fi

