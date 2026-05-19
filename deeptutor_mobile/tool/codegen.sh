#!/usr/bin/env bash
# Runs build_runner once for the project. Used in CI and locally
# (`tool/codegen.sh` from the deeptutor_mobile directory).
set -euo pipefail

flutter pub get
dart run build_runner build --delete-conflicting-outputs
