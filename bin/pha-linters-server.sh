#!/bin/sh

VAR="./.var/portable-hack-ast-linters-server"
VSCODE="./.vscode"
VSCODE_EXTENSIONS="./.vscode/extensions.json"
VSCODE_SETTINGS="./.vscode/settings.json"
DOCKER_COMPOSE_YML="./docker-compose.yml"
RESOURCE_NAME="portable-hack-ast-linters-server-bundled.resource"
RESOURCE="$(find . -type f -name "$RESOURCE_NAME" | head -n 1)"
PORT_NUMBER=10641
SETUP_DOCKER_NATIVE_ENV=No
TRUSTS_RESOURCE=No
HAS_CHANGED=No
LAUNCH_MODE=server

print_help_text() {
  echo "Documentation can be found at https://github.com/hershel-theodore-layton/portable-hack-ast-linters-server/blob/master/README.md"
  echo "This script will do the following steps:"
  echo "  * Find the PhaLinters bundle"
  echo "  * Compile a repo auth hhbc file if it is missing or out of date"
  echo "  * Start an http server on localhost on the specified port, defaults to 10641."
  echo "Supported options:"
  echo "  -h <no argument> print this help text"
  echo "  -g <no argument> install globally, installation in /var instead of .var"
  echo "  -p <port for the server to listen on>"
  echo "  -b (or -r) <path to bundle> implies trust in the resource bundle"
  echo "  -t <no argument> force trust the resource bundle found by this script"
  echo "  -s <no argument> setup .vscode/settings.json for Docker Native development"
  echo "  -d <no argument> run the server as a daemon, return control to the shell"
}

setup_docker_native_environment() {
  mkdir -p "$VSCODE" 2> /dev/null

  if [ -f $VSCODE_SETTINGS ]; then
    return
  fi

  linter_port=`cat $DOCKER_COMPOSE_YML | grep -A 1 'ports' | cut -d ':' -f 1 | grep -E -o '[[:digit:]]{5}'`
  container_name=`cat $DOCKER_COMPOSE_YML | grep 'container_name' | cut -d ':' -f 2`

cat << JSON > $VSCODE_SETTINGS
{
  "editor.detectIndentation": false,
  "editor.tabSize": 2,
  "editor.rulers": [80],
  "hack.remote.docker.containerName": "$container_name",
  "hack.remote.enabled": true,
  "hack.remote.type": "docker",
  "hack.remote.workspacePath": "/mnt/project",
  "lintServer.uri": "http://localhost:$linter_port?action=lint-input&format=vscode-json"
}
JSON

cat << JSON > $VSCODE_EXTENSIONS
{
  "recommendations": [
    "pranayagarwal.vscode-hack",
    "hershel-theodore-layton.dead-simple-lint-server-integration"
  ]
}
JSON
}

compile_repo_auth() {
  HAS_CHANGED=Yes
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

while getopts "p:b:r:htgs" opt; do
  case "$opt" in
    h)  print_help_text && exit 0
      ;;
    b)  RESOURCE=$OPTARG
        TRUSTS_RESOURCE=Yes
      ;;
    r)  RESOURCE=$OPTARG
        TRUSTS_RESOURCE=Yes
      ;;
    p)  PORT_NUMBER=$OPTARG
      ;;
    t)  TRUSTS_RESOURCE=Yes
      ;;
    g)  VAR="/var/tmp/portable-hack-ast-linters-server"
      ;;
    s)  SETUP_DOCKER_NATIVE_ENV=Yes
      ;;
    d)  LAUNCH_MODE=daemon
      ;;
    *) echo "Unknown flag $opt"
      ;;
  esac
done

if [ ! -f .hhconfig ]; then
    echo "Are you in the root directory of your project?" >&2
    exit 1
fi

if [ "$SETUP_DOCKER_NATIVE_ENV" = "Yes" ]; then
  setup_docker_native_environment
fi

if [ ! -f "$VAR/hhvm.hhbc" ]; then
  compile_repo_auth
fi

OLD_SHA="$(cat $VAR/sha1sum.txt)"
NEW_SHA="$(sha1sum "$RESOURCE")"

if [ "$OLD_SHA" != "$NEW_SHA" ]; then
  compile_repo_auth
fi

if [ -f "$VAR/www.pid" ]; then
  PID="$(cat $VAR/www.pid)"

  url="http://localhost:$PORT_NUMBER/?action=identify-yourself"
  identity=$(curl --silent $url)
  
  if [ "$HAS_CHANGED" = "No" ] && [ "$identity" = "HTL\PhaLintersServer" ]; then
    echo "Previous server is identical, nothing to do."
    exit
  fi

  if [ "$identity" = "HTL\PhaLintersServer" ]; then
    echo "Previous server is different, replacing it."
    kill "$PID" && rm "$var/www.pid"
  else
    echo "Previous server left a dangling www.pid."
  fi
fi

hhvm -m $LAUNCH_MODE -p "$PORT_NUMBER" \
  --no-config \
  -vServer.AllowRunAsRoot=1 \
  -dhhvm.repo.authoritative=true \
  -dhhvm.repo.path=$VAR/hhvm.hhbc \
  "-dhhvm.server.global_document=""$RESOURCE""" \
  -dhhvm.jit_retranslate_all_request=5 \
  "-dhhvm.php_file.extensions[resource]=1" \
  -dhhvm.pid_file=$VAR/www.pid