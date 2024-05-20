#!/bin/sh

VAR="./.var/portable-hack-ast-linters-server"
RESOURCE_NAME="portable-hack-ast-linters-server-bundled.resource"
RESOURCE="$(find . -type f -name "$RESOURCE_NAME" | head -n 1)"
PORT_NUMBER=10641
TRUSTS_RESOURCE=No

print_help_text() {
  echo "Documentation can be found at https://github.com/hershel-theodore-layton/portable-hack-ast-linters-server/blob/master/README.md"
  echo "This script will do the following steps:"
  echo "  * Find the PhaLinters bundle"
  echo "  * Compile a repo auth hhbc file if it is missing or out of date"
  echo "  * Start an http server on localhost on the specified port, defaults to 10641."
  echo "Supported options:"
  echo "  -p <port for the server to listen on>"
  echo "  -b <path to bundle> implies trust in the resource bundle"
  echo "  -t <no argument> force trust the resource bundle found by this script"
}

compile_repo_auth() {
  mkdir -p "$VAR" 2> /dev/null

  if [ "$TRUSTS_RESOURCE" != "Yes" ]; then
    echo "Found the following resource file."
    echo "$RESOURCE"
    echo "If you trust the resource above, type 'I trust this resource' to build and run it."

    read -r CONFIRMATION
    if [ "$CONFIRMATION" != "I trust this resource" ]; then
      echo "Stopping..."
      exit 1
    fi
  fi

  hhvm --hphp "$RESOURCE" --output-dir "$VAR"
  sha1sum "$RESOURCE" > "$VAR/sha1sum.txt"
}

while getopts "p:b:ht" opt; do
  case "$opt" in
    h)  print_help_text && exit 0
      ;;
    b)  RESOURCE=$OPTARG
        TRUSTS_RESOURCE=Yes
      ;;
    p)  PORT_NUMBER=$OPTARG
      ;;
    t)  TRUSTS_RESOURCE=Yes
      ;;
    *) echo "Unknown flag $opt"
      ;;
  esac
done

if [ ! -f .hhconfig ]; then
    echo "Are you in the root directory of your project?" >&2
    exit 1
fi

if [ ! -f .var/portable-hack-ast-linters-server/hhvm.hhbc ]; then
  compile_repo_auth
fi

OLD_SHA="$(cat $VAR/sha1sum.txt)"
NEW_SHA="$(sha1sum "$RESOURCE")"

if [ "$OLD_SHA" != "$NEW_SHA" ]; then
  compile_repo_auth
fi

hhvm -m server -p "$PORT_NUMBER" \
  -vServer.AllowRunAsRoot=1 \
  -dhhvm.repo.authoritative=true \
  -dhhvm.repo.path=/mnt/project/.var/portable-hack-ast-linters-server/hhvm.hhbc \
  -dhhvm.server.global_document=bin/portable-hack-ast-linters-server-bundled.resource \
  -dhhvm.jit_retranslate_all_request=5 \
  "-dhhvm.php_file.extensions[resource]=1"