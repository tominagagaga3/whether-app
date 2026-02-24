#!/usr/bin/env bash
set -euo pipefail
set -x

FLUTTER_TAR="flutter_linux_3.24.5-stable.tar.xz"

curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_TAR}" | tar -xJ

export PATH="$PWD/flutter/bin:$PATH"

git config --global --add safe.directory '*'

flutter --version 
flutter pub get
flutter build web --release