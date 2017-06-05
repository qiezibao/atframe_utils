#!/bin/sh

SYS_NAME="$(uname -s)";
SYS_NAME="$(basename $SYS_NAME)";

BUILD_DIR=$(echo "build_$SYS_NAME" | tr '[:upper:]' '[:lower:]');

cd "$(dirname $0)";
mkdir -p "$BUILD_DIR";
cd "$BUILD_DIR";

cmake .. -DPROJECT_ENABLE_UNITTEST=ON -DPROJECT_ENABLE_SAMPLE=ON "$@";
