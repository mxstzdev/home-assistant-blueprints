#!/bin/bash
#
# Prints the Home Assistant versions each blueprint is validated against, as
# JSON for the CI matrix: {"blocking": [...], "scheduled": [...]}.
#
# Each entry has the blueprint folder, the target (min, stable or dev), the
# image tag and a skip reason, empty if the check runs. Blocking entries must
# pass on every run, scheduled ones only on scheduled and manual runs.
#
# - min runs on its own image, is left out when it equals stable, and runs on
#   the beta or dev build of the release when min_version is not released yet.
# - stable is skipped when min_version is not released yet.
# - dev is the latest nightly, left out when min already runs on it.
#
# The current versions come from the Home Assistant version service. Set
# HA_STABLE, HA_BETA and HA_DEV to use other versions, e.g. for tests.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly VERSION_URL="https://version.home-assistant.io"
readonly RELEASE_RE='^[0-9]+\.[0-9]+\.[0-9]+'

# Provides read_min_version.
# shellcheck source=scripts/validate-blueprint.sh
source "${ROOT_DIR}/scripts/validate-blueprint.sh"

#######################################
# Prints an error message, as a GitHub annotation inside GitHub Actions.
# Globals:
#   GITHUB_ACTIONS
# Arguments:
#   Message to print.
# Outputs:
#   Writes the message to STDERR, since STDOUT holds the JSON.
#######################################
err() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::error::$*" >&2
  else
    echo "error: $*" >&2
  fi
}

#######################################
# Prints the current Home Assistant version of a channel.
# Arguments:
#   Channel: stable, beta or dev.
#   Pattern the version must match.
#   Version to use instead of the version service, may be empty.
# Outputs:
#   Writes the version to STDOUT.
# Returns:
#   Non-zero if the version cannot be read or has an unexpected format.
#######################################
channel_version() {
  local channel="$1" pattern="$2" version="$3"
  if [[ -z "${version}" ]]; then
    version="$(curl -fsSL --retry 3 "${VERSION_URL}/${channel}.json" \
      | jq -r '.homeassistant.default')" || {
      err "cannot read the ${channel} version from ${VERSION_URL}"
      return 1
    }
  fi
  if [[ ! "${version}" =~ ${pattern} ]]; then
    err "unexpected ${channel} version '${version}'"
    return 1
  fi
  echo "${version}"
}

#######################################
# Prints the release a version leads to, e.g. 2026.12.0b1 -> 2026.12.0.
# Arguments:
#   Version.
# Outputs:
#   Writes the release to STDOUT.
#######################################
release_of() {
  [[ "$1" =~ ${RELEASE_RE} ]]
  echo "${BASH_REMATCH[0]}"
}

#######################################
# Compares two X.Y.Z versions.
# Arguments:
#   Two versions.
# Outputs:
#   Writes -1, 0 or 1 to STDOUT if the first is older, equal or newer.
#######################################
compare_versions() {
  if [[ "$1" == "$2" ]]; then
    echo 0
  elif [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" == "$1" ]]; then
    echo -1
  else
    echo 1
  fi
}

#######################################
# Prints one matrix entry.
# Arguments:
#   Blueprint folder, target, image tag, skip reason.
# Outputs:
#   Writes the entry as compact JSON and a newline to STDOUT.
#######################################
entry() {
  jq -nc --arg blueprint "$1" --arg ha "$2" --arg version "$3" \
    --arg skip "$4" \
    '{blueprint: $blueprint, ha: $ha, version: $version, skip: $skip}'
}

main() {
  local stable beta dev
  stable="$(channel_version stable '^[0-9]+\.[0-9]+\.[0-9]+$' \
    "${HA_STABLE:-}")"
  beta="$(channel_version beta '^[0-9]+\.[0-9]+\.[0-9]+(b[0-9]+)?$' \
    "${HA_BETA:-}")"
  dev="$(channel_version dev '^[0-9]+\.[0-9]+\.[0-9]+\.dev[0-9]+$' \
    "${HA_DEV:-}")"
  # Without a beta, the beta channel points to the stable release.
  if [[ "${beta}" != *b* ]]; then
    beta=""
  fi

  local blocking="" scheduled="" dir min_version
  local blueprints
  blueprints="$(bash "${ROOT_DIR}/scripts/list-blueprints.sh" | jq -r '.[]')"
  for dir in ${blueprints}; do
    min_version="$(read_min_version \
      "${ROOT_DIR}/${dir}/$(basename "${dir}").yaml")"
    if [[ -z "${min_version}" ]]; then
      err "${dir}: blueprint.homeassistant.min_version is required"
      return 1
    fi

    case "$(compare_versions "${min_version}" "${stable}")" in
      -1)
        blocking+="$(entry "${dir}" min "${min_version}" "")"$'\n'
        blocking+="$(entry "${dir}" stable "${stable}" "")"$'\n'
        scheduled+="$(entry "${dir}" dev "${dev}" "")"$'\n'
        ;;
      0)
        blocking+="$(entry "${dir}" stable "${stable}" "")"$'\n'
        scheduled+="$(entry "${dir}" dev "${dev}" "")"$'\n'
        ;;
      1)
        if [[ -n "${beta}" \
          && "$(release_of "${beta}")" == "${min_version}" ]]; then
          blocking+="$(entry "${dir}" min "${beta}" "")"$'\n'
          scheduled+="$(entry "${dir}" dev "${dev}" "")"$'\n'
        elif [[ "$(release_of "${dev}")" == "${min_version}" ]]; then
          blocking+="$(entry "${dir}" min "${dev}" "")"$'\n'
        else
          err "${dir}: min_version ${min_version} is not released, and no" \
            "beta or dev build leads to it (stable ${stable}," \
            "beta ${beta:-none}, dev ${dev})"
          return 1
        fi
        blocking+="$(entry "${dir}" stable "${stable}" \
          "min_version ${min_version} is not released yet")"$'\n'
        ;;
    esac
  done

  jq -nc --argjson blocking "$(jq -sc . <<< "${blocking}")" \
    --argjson scheduled "$(jq -sc . <<< "${scheduled}")" \
    '{blocking: $blocking, scheduled: $scheduled}'
}

main "$@"
