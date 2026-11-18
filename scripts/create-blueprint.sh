#!/bin/bash
#
# Creates the skeleton of a new blueprint and registers it for releases.
#
# Creates blueprints/<domain>/<name>/ with the blueprint YAML, README.md,
# CHANGELOG.md and tests/<domain>.yaml, adds the package to
# release-please-config.json and prints the row for the README table.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly OWNER="mxstzdev"
readonly REPO="home-assistant-blueprints"
readonly GITHUB_URL="https://github.com/${OWNER}/${REPO}"
readonly MY_HA_URL="https://my.home-assistant.io"
readonly IMPORT_BADGE="${MY_HA_URL}/badges/blueprint_import.svg"
readonly KOFI_URL="https://ko-fi.com/${OWNER}"
readonly BLUEPRINTS_MENU="Settings → Automations & Scenes → Blueprints"
readonly INITIAL_VERSION="0.1.0"
readonly DEFAULT_DOMAIN="automation"
readonly DEFAULT_MIN_VERSION="2025.1.0"
readonly RELEASE_CONFIG="${ROOT_DIR}/release-please-config.json"
USAGE="Usage: $(basename "$0") [-d automation|script] [-m min_version] <name>"
readonly USAGE

#######################################
# Prints an error message.
# Arguments:
#   Message to print.
# Outputs:
#   Writes the message to STDERR.
#######################################
err() {
  echo "error: $*" >&2
}

#######################################
# Turns a kebab-case name into a title, e.g. motion-light -> Motion light.
# Arguments:
#   Blueprint name.
# Outputs:
#   Writes the title to STDOUT.
#######################################
to_title() {
  local title="${1//-/ }"
  echo "${title^}"
}

#######################################
# Percent-encodes the characters of a GitHub URL that need it.
# Arguments:
#   URL to encode.
# Outputs:
#   Writes the encoded URL to STDOUT.
#######################################
url_encode() {
  local url="${1//:/%3A}"
  echo "${url//\//%2F}"
}

#######################################
# Prints the Version badge. It uses the static endpoint because release-please
# would read the "-blue" of "version-X.Y.Z-blue" as a prerelease suffix.
# Globals:
#   INITIAL_VERSION
# Arguments:
#   CHANGELOG link.
# Outputs:
#   Writes the badge to STDOUT.
#######################################
version_badge() {
  local changelog_url="$1"

  echo "[![Version](https://img.shields.io/static/v1?label=version&message=${INITIAL_VERSION}&color=blue)](${changelog_url})"
}

#######################################
# Prints the README badges on one line: License, Version and Home Assistant.
# release-please replaces the first version on the marked line, so the Version
# badge must stay the first versioned badge.
# Arguments:
#   min_version.
# Outputs:
#   Writes the badges to STDOUT.
#######################################
readme_badges() {
  local min_version="$1"
  local shields="https://img.shields.io"

  echo "[![License](${shields}/badge/license-MIT-blue)](../../../LICENSE)" \
    "$(version_badge CHANGELOG.md)" \
    "[![Home Assistant](${shields}/badge/Home%20Assistant-%E2%89%A5%20${min_version}-41BDF5?logo=homeassistant&logoColor=white)](https://www.home-assistant.io/)" \
    "<!-- x-release-please-version -->"
}

#######################################
# Writes the blueprint YAML file.
# Globals:
#   GITHUB_URL
#   KOFI_URL
#   OWNER
# Arguments:
#   Target file, domain, name, title, source URL, package path, min_version.
#######################################
write_blueprint() {
  local file="$1" domain="$2" name="$3" title="$4" source_url="$5"
  local path="$6" min_version="$7"
  local badge_lines
  badge_lines="    $(version_badge "${GITHUB_URL}/blob/main/${path}/CHANGELOG.md")"
  badge_lines+=" <!-- x-release-please-version -->"

  cat > "${file}" <<EOF
blueprint:
  name: ${title}
  # yamllint disable rule:line-length
  description: |
${badge_lines}

    TODO: Describe what the blueprint does.

    [Documentation](${GITHUB_URL}/tree/main/${path}) · [Changelog](${GITHUB_URL}/blob/main/${path}/CHANGELOG.md)

    [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](${KOFI_URL})
  # yamllint enable rule:line-length
  domain: ${domain}
  author: ${OWNER}
  source_url: ${source_url}
  homeassistant:
    min_version: "${min_version}"
  input:
    entity:
      name: Entity
      description: "TODO: Replace with the blueprint's inputs."
      selector:
        entity: {}

mode: single
EOF

  case "${domain}" in
    automation)
      cat >> "${file}" <<'EOF'

triggers:
  - trigger: state
    entity_id: !input entity

conditions: []

actions:
  - stop: "TODO: Replace with the blueprint's actions."
EOF
      ;;
    script)
      cat >> "${file}" <<'EOF'

sequence:
  - variables:
      entity: !input entity
  - stop: "TODO: Replace with the blueprint's actions."
EOF
      ;;
  esac
}

#######################################
# Writes the sample usage that CI validates the blueprint with.
# Globals:
#   OWNER
# Arguments:
#   Target file, domain, name.
#######################################
write_fixture() {
  local file="$1" domain="$2" name="$3"
  local usage="use_blueprint:
    path: ${OWNER}/${name}.yaml
    input:
      entity: sensor.example"

  case "${domain}" in
    automation) printf -- '- alias: Sample\n  %s\n' "${usage}" > "${file}" ;;
    script) printf 'sample:\n  %s\n' "${usage}" > "${file}" ;;
  esac
}

#######################################
# Writes the blueprint README.md.
# Globals:
#   BLUEPRINTS_MENU
#   IMPORT_BADGE
# Arguments:
#   Target file, domain, title, source URL, import URL, min_version.
#######################################
write_readme() {
  local file="$1" domain="$2" title="$3" source_url="$4" import_url="$5"
  local min_version="$6"
  local fence='```'

  cat > "${file}" <<EOF
# ${title}

$(readme_badges "${min_version}")

TODO: Describe what the blueprint does.

## Requirements

- Home Assistant ${min_version} or newer

## Installation

1. Import the blueprint:

   [![Import](${IMPORT_BADGE})](${import_url})

   Or, in Home Assistant, go to **${BLUEPRINTS_MENU} → Import Blueprint**
   and paste this URL:

   ${fence}text
   ${source_url}
   ${fence}

2. Open **${title}** in the blueprint list and click **Create ${domain}**.
3. Fill in the inputs; see [Inputs](#inputs).

## Updating

1. In **${BLUEPRINTS_MENU}**, open the menu (⋮) of **${title}**
   and choose **Re-import blueprint**.
2. Confirm overwriting the existing file. Your ${domain}s use the new version right away.

> [!NOTE]
> The installed version is shown in the Version badge at the top of the blueprint's
> description.

> [!WARNING]
> Major versions can rename or remove inputs. Read the [CHANGELOG.md](CHANGELOG.md) before updating
> across a major version.

## Inputs

| Input | Description | Default |
| ----- | ----------- | ------- |
| Entity | TODO | |

## License

[MIT](../../../LICENSE)
EOF
}

#######################################
# Writes CHANGELOG.md. release-please adds the entries on each release.
# Arguments:
#   Target file.
#######################################
write_changelog() {
  echo '<!-- Generated by release-please. Do not edit. -->' > "$1"
}

#######################################
# Adds the blueprint as a package to the release-please config.
# Globals:
#   RELEASE_CONFIG
# Arguments:
#   Package path relative to the repository root, name.
#######################################
register_package() {
  local path="$1" name="$2"
  local tmp
  tmp="$(mktemp)"

  jq --arg path "${path}" --arg name "${name}" '
    .packages[$path] = {
      component: $name,
      "extra-files": [
        {type: "generic", path: ($name + ".yaml")},
        {type: "generic", path: "README.md"}
      ]
    }
    | .packages |= (to_entries | sort_by(.key) | from_entries)
  ' "${RELEASE_CONFIG}" > "${tmp}"
  mv "${tmp}" "${RELEASE_CONFIG}"
}

main() {
  local domain="${DEFAULT_DOMAIN}"
  local min_version="${DEFAULT_MIN_VERSION}"
  local opt

  while getopts 'd:m:h' opt; do
    case "${opt}" in
      d) domain="${OPTARG}" ;;
      m) min_version="${OPTARG}" ;;
      h)
        echo "${USAGE}"
        exit 0
        ;;
      *)
        err "${USAGE}"
        exit 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  if (( $# != 1 )); then
    err "${USAGE}"
    exit 1
  fi
  local -r name="$1"

  if [[ ! "${name}" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]]; then
    err "name must be lowercase kebab-case, got '${name}'"
    exit 1
  fi
  if [[ "${domain}" != "automation" && "${domain}" != "script" ]]; then
    err "domain must be 'automation' or 'script', got '${domain}'"
    exit 1
  fi
  if [[ ! "${min_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    err "min_version must be X.Y.Z, got '${min_version}'"
    exit 1
  fi
  if ! command -v jq > /dev/null; then
    err "jq is required"
    exit 1
  fi

  local -r path="blueprints/${domain}/${name}"
  local -r dir="${ROOT_DIR}/${path}"
  # The name is the release-please component and tag prefix, so it must be
  # unique across domains.
  local existing
  for existing in "${ROOT_DIR}"/blueprints/*/"${name}"; do
    if [[ -e "${existing}" ]]; then
      err "${existing#"${ROOT_DIR}/"} already exists; names must be unique" \
        "across domains"
      exit 1
    fi
  done
  if jq -e --arg path "${path}" --arg name "${name}" \
    '.packages | has($path) or any(.[]; .component == $name)' \
    "${RELEASE_CONFIG}" > /dev/null; then
    err "${name} is already registered in release-please-config.json"
    exit 1
  fi

  local title source_url import_url
  title="$(to_title "${name}")"
  source_url="${GITHUB_URL}/blob/main/${path}/${name}.yaml"
  import_url="${MY_HA_URL}/redirect/blueprint_import/"
  import_url+="?blueprint_url=$(url_encode "${source_url}")"

  mkdir -p "${dir}/tests"
  write_blueprint "${dir}/${name}.yaml" "${domain}" "${name}" "${title}" \
    "${source_url}" "${path}" "${min_version}"
  write_fixture "${dir}/tests/${domain}.yaml" "${domain}" "${name}"
  write_readme "${dir}/README.md" "${domain}" "${title}" "${source_url}" \
    "${import_url}" "${min_version}"
  write_changelog "${dir}/CHANGELOG.md"
  register_package "${path}" "${name}"

  echo "Created ${path} and registered it in release-please-config.json."
  local section
  section="$(to_title "${domain}")s"
  echo "Add this row to the table under '### ${section}' in README.md:"
  echo
  echo "| [${title}](${path}) | TODO |"
}

main "$@"
