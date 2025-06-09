#!/bin/sh
find vendor -name '*.php' -delete
rm -r vendor/hershel-theodore-layton/portable-hack-ast/bin
hh_client --concatenate-all src vendor \
  > bin/portable-hack-ast-linters-server-bundled.resource
