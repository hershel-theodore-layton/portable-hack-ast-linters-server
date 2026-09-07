#!/bin/sh
# portable-hack-ast-linters-server is MIT licensed, see /LICENSE.
set -eu
if [ "$#" -ne 1 ]; then
  echo 'Usage: pha-sign-hack-source.sh FILE' >&2
  exit 1
fi
exec hhvm -dhhvm.jit=0 "$(dirname "$(readlink -f "$0")")/portable-hack-ast-linters-server-bundled.resource" sign-file "$1"
