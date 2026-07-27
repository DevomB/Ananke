#!/usr/bin/env bash
set -euo pipefail

if ! command -v opam >/dev/null 2>&1; then
  echo "opam is required: https://ocaml.org/docs/opam-install"
  exit 1
fi

opam switch create . 5.2.0 --yes --deps-only 2>/dev/null || opam switch set .
opam install . --deps-only --with-test --yes
dune build
dune runtest
echo "ananke ready"
