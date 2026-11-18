#!/bin/bash
#
# Validates one blueprint against a Home Assistant version with check_config
# and an import round trip.
#
# The blueprint and its tests/<domain>.yaml are copied into a throwaway
# configuration, which is checked inside the official Home Assistant image.
# Set HA_PYTHON to a Python with the homeassistant package to skip Docker.

set -euo pipefail

readonly NAMESPACE="mxstzdev"
readonly IMAGE="ghcr.io/home-assistant/home-assistant"
USAGE="Usage: $(basename "$0") <blueprint-dir> <min|stable|X.Y.Z>"
readonly USAGE
readonly MIN_VERSION_SED="s/^[[:space:]]+min_version:[[:space:]]*[\"']?\
([0-9]+\.[0-9]+(\.[0-9]+)?)[\"']?.*/\1/p"
# check_config ignores min_version, so it is compared explicitly.
readonly VERSION_CHECK='
import sys
from awesomeversion import AwesomeVersion
from homeassistant.const import __version__ as current
required = sys.argv[1]
print(f"Home Assistant {current}")
if AwesomeVersion(current) < AwesomeVersion(required):
    print(f"ERROR: Home Assistant {current} is older than {required}")
'
# check_config reads the blueprint as written. Importing it saves the
# validated data instead, which must load again (e.g. supported_features).
readonly IMPORT_CHECK='
import sys
from pathlib import Path
from homeassistant.components.blueprint.models import Blueprint
from homeassistant.components.blueprint.schemas import BLUEPRINT_SCHEMA
from homeassistant.util.yaml import parse_yaml
path = Path(sys.argv[1])
try:
    saved = Blueprint(parse_yaml(path.read_text()), schema=BLUEPRINT_SCHEMA).yaml()
    Blueprint(parse_yaml(saved), schema=BLUEPRINT_SCHEMA)
except Exception as err:
    print(f"ERROR: {path.name} is invalid after import: {err}")
else:
    print(f"Import round trip of {path.name}: OK")
'

# Temporary files, removed on exit.
work_dir=""

#######################################
# Prints an error message, as a GitHub annotation inside GitHub Actions.
# Globals:
#   GITHUB_ACTIONS
# Arguments:
#   Message to print.
# Outputs:
#   Writes the message to STDOUT in GitHub Actions, to STDERR otherwise.
#######################################
err() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::error::$*"
  else
    echo "error: $*" >&2
  fi
}

#######################################
# Removes the temporary files.
# Globals:
#   work_dir
#######################################
cleanup() {
  if [[ -n "${work_dir}" ]]; then
    rm -rf "${work_dir}"
  fi
}

#######################################
# Reads blueprint.homeassistant.min_version, normalized to X.Y.Z.
# Globals:
#   MIN_VERSION_SED
# Arguments:
#   Blueprint file.
# Outputs:
#   Writes the version to STDOUT, nothing if it is not declared.
#######################################
read_min_version() {
  local version
  version="$(sed -nE "${MIN_VERSION_SED}" "$1" | head -n 1)"
  # Image tags always carry a patch version.
  if [[ "${version}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    version+=".0"
  fi
  echo "${version}"
}

#######################################
# Runs the min_version check, check_config and the import round trip.
# Globals:
#   HA_PYTHON
#   IMAGE
#   IMPORT_CHECK
#   VERSION_CHECK
# Arguments:
#   Configuration directory, Home Assistant image tag, min_version,
#   blueprint path relative to the configuration directory.
# Outputs:
#   Writes the combined output to STDOUT.
# Returns:
#   Non-zero if a command failed.
#######################################
run_checks() {
  local config="$1" version="$2" min_version="$3" blueprint="$4"

  if [[ -n "${HA_PYTHON:-}" ]]; then
    "${HA_PYTHON}" -c "${VERSION_CHECK}" "${min_version}" \
      && "${HA_PYTHON}" -m homeassistant --script check_config \
        --config "${config}" \
      && "${HA_PYTHON}" -c "${IMPORT_CHECK}" "${config}/${blueprint}"
  else
    docker run --rm --entrypoint python "${IMAGE}:${version}" \
      -c "${VERSION_CHECK}" "${min_version}" \
      && docker run --rm --volume "${config}:/config:ro" \
        --entrypoint python "${IMAGE}:${version}" \
        -m homeassistant --script check_config --config /config \
      && docker run --rm --volume "${config}:/config:ro" \
        --entrypoint python "${IMAGE}:${version}" \
        -c "${IMPORT_CHECK}" "/config/${blueprint}"
  fi
}

main() {
  if (( $# != 2 )); then
    err "${USAGE}"
    exit 1
  fi

  local -r dir="${1%/}"
  local -r target="$2"
  local name domain
  name="$(basename "${dir}")"
  domain="$(basename "$(dirname "${dir}")")"
  local -r blueprint="${dir}/${name}.yaml"
  local -r fixture="${dir}/tests/${domain}.yaml"

  case "${domain}" in
    automation | script) ;;
    *)
      err "${dir}: domain must be 'automation' or 'script', got '${domain}'"
      exit 1
      ;;
  esac
  local file
  for file in "${blueprint}" "${dir}/README.md" "${fixture}"; do
    if [[ ! -f "${file}" ]]; then
      err "missing ${file}"
      exit 1
    fi
  done

  local min_version
  min_version="$(read_min_version "${blueprint}")"
  if [[ -z "${min_version}" ]]; then
    err "${blueprint}: blueprint.homeassistant.min_version is required"
    exit 1
  fi
  # The Home Assistant badge is only in the README: Home Assistant itself refuses blueprints
  # that need a newer version.
  if ! grep -qF "Home%20Assistant-%E2%89%A5%20${min_version}-" "${dir}/README.md"; then
    err "${dir}/README.md: Home Assistant badge must show ${min_version}"
    exit 1
  fi

  local version
  case "${target}" in
    min) version="${min_version}" ;;
    stable | [0-9]*.[0-9]*.[0-9]*) version="${target}" ;;
    *)
      err "version must be 'min', 'stable' or X.Y.Z, got '${target}'"
      exit 1
      ;;
  esac

  work_dir="$(mktemp -d)"
  trap cleanup EXIT
  local -r config="${work_dir}/config"
  local -r log="${work_dir}/check.log"
  local -r installed="blueprints/${domain}/${NAMESPACE}/${name}.yaml"
  mkdir -p "${config}/blueprints/${domain}/${NAMESPACE}"
  cp "${blueprint}" "${config}/${installed}"
  cp "${fixture}" "${config}/${domain}.yaml"
  echo "${domain}: !include ${domain}.yaml" > "${config}/configuration.yaml"

  echo "Validating ${blueprint} on Home Assistant ${version}" \
    "(min_version ${min_version})"
  local status=0
  run_checks "${config}" "${version}" "${min_version}" "${installed}" \
    > "${log}" 2>&1 \
    || status=$?
  cat "${log}"

  # check_config exits 0 for invalid automations and scripts; it only logs.
  if (( status != 0 )) \
    || grep -qE '^(ERROR|CRITICAL)|Failed config|Invalid config' "${log}"; then
    err "${blueprint} is invalid on Home Assistant ${version}"
    exit 1
  fi
  echo "OK: ${blueprint} is valid on Home Assistant ${version}"
}

main "$@"
