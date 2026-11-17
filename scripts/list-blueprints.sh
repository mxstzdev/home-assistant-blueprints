#!/bin/bash
#
# Prints all blueprint folders (blueprints/<domain>/<name>) as a JSON array.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

main() {
  cd "${ROOT_DIR}"

  if [[ ! -d blueprints ]]; then
    echo '[]'
    return
  fi

  find blueprints -mindepth 2 -maxdepth 2 -type d \
    | LC_ALL=C sort \
    | jq --raw-input --slurp --compact-output \
      'split("\n") | map(select(length > 0))'
}

main "$@"
