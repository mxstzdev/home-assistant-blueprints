#!/bin/bash
#
# Runs the GitHub pull request workflow: creates a branch, opens a pull
# request for it and removes the branch once its pull request is closed.
#
# Needs git and the GitHub CLI (gh), signed in with `gh auth login`.
#
# Commands:
#   create-branch [<scope>/<topic>] Create a branch from the latest default
#                                   branch. Without a name, or with an invalid
#                                   one in a terminal, asks for scope and topic.
#   open-pr [<branch>] [-- <gh args>]
#                                   Push a branch (default: the current one)
#                                   with upstream and open its pull request.
#   delete-branch [<branch>]        Delete a branch whose pull request is
#                                   merged or closed, local and remote.
#   cleanup-repo                    Delete the local and remote leftovers of
#                                   merged or closed pull requests, after asking.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly REMOTE="origin"
# Scopes for branches that are not tied to one blueprint.
readonly GENERAL_SCOPES=(ci docs repo scripts)
readonly NAME_PATTERN='^[a-z0-9]+(-[a-z0-9]+)*$'
USAGE="Usage: $(basename "$0") create-branch [<scope>/<topic>] | open-pr [<branch>] [-- <gh args>] | delete-branch [<branch>] | cleanup-repo"
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
# Asks a yes/no question. Answers no when STDIN is not a terminal.
# Arguments:
#   Question to ask.
# Returns:
#   0 for yes, 1 otherwise.
#######################################
confirm() {
  local answer

  [[ -t 0 ]] || return 1
  read -r -p "$1 [y/N] " answer
  [[ "${answer}" == [yY] ]]
}

#######################################
# Prints the default branch of the remote, falling back to main.
# Globals:
#   REMOTE
# Outputs:
#   Writes the branch name to STDOUT.
#######################################
default_branch() {
  local ref

  if ref="$(git symbolic-ref --quiet --short "refs/remotes/${REMOTE}/HEAD")"; then
    echo "${ref#"${REMOTE}/"}"
  else
    echo "main"
  fi
}

#######################################
# Prints the current branch, or nothing on a detached HEAD.
# Outputs:
#   Writes the branch name to STDOUT.
#######################################
current_branch() {
  git symbolic-ref --quiet --short HEAD || true
}

#######################################
# Fails when the working tree has uncommitted changes.
#######################################
require_clean_tree() {
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    err "the working tree has uncommitted changes, commit or stash them first"
    exit 1
  fi
}

#######################################
# Prints the allowed branch scopes: general scopes, then blueprint folders.
# Globals:
#   GENERAL_SCOPES
#   ROOT_DIR
# Outputs:
#   Writes one scope per line to STDOUT.
#######################################
branch_scopes() {
  printf '%s\n' "${GENERAL_SCOPES[@]}"
  if [[ -d "${ROOT_DIR}/blueprints" ]]; then
    find "${ROOT_DIR}/blueprints" -mindepth 2 -maxdepth 2 -type d -printf '%f\n' \
      | LC_ALL=C sort
  fi
}

#######################################
# Checks a branch name against the <scope>/<topic> schema.
# Globals:
#   NAME_PATTERN
# Arguments:
#   Branch name.
# Outputs:
#   Writes the reason to STDERR when the name is invalid.
# Returns:
#   0 when the name is valid, 1 otherwise.
#######################################
validate_branch_name() {
  local -r name="$1"
  local -r scope="${name%%/*}"
  local -r topic="${name#*/}"

  if [[ "${name}" != */* || ! "${scope}" =~ ${NAME_PATTERN} \
      || ! "${topic}" =~ ${NAME_PATTERN} ]]; then
    err "branch must be <scope>/<topic> in lowercase kebab-case, got '${name}'"
    return 1
  fi
  local scopes
  mapfile -t scopes < <(branch_scopes)
  if [[ ! " ${scopes[*]} " == *" ${scope} "* ]]; then
    err "unknown scope '${scope}', use a blueprint name or one of: ${GENERAL_SCOPES[*]}"
    return 1
  fi
}

#######################################
# Turns free text into kebab-case, e.g. "Dependabot integration" ->
# dependabot-integration. Spells out German umlauts and drops other characters
# that are not ASCII letters or digits.
# Arguments:
#   Text to convert.
# Outputs:
#   Writes the converted text to STDOUT.
#######################################
to_kebab_case() {
  local text

  text="$(sed -e 's/ä/ae/g; s/Ä/ae/g; s/ö/oe/g; s/Ö/oe/g; s/ü/ue/g; s/Ü/ue/g; s/ß/ss/g' <<< "$1" \
    | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | LC_ALL=C sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  echo "${text}"
}

#######################################
# Asks for scope and topic of a new branch. Converts the topic to kebab-case.
# Globals:
#   NAME_PATTERN
# Outputs:
#   Writes the prompts to STDERR and the branch name to STDOUT.
#######################################
prompt_branch_name() {
  local scope topic
  local scopes

  mapfile -t scopes < <(branch_scopes)
  PS3="Scope: "
  select scope in "${scopes[@]}"; do
    [[ -n "${scope}" ]] && break
  done
  [[ -n "${scope}" ]] || exit 1

  while true; do
    read -r -p "Topic: " topic || exit 1
    topic="$(to_kebab_case "${topic}")"
    [[ "${topic}" =~ ${NAME_PATTERN} ]] && break
    err "topic needs at least one letter or digit"
  done
  echo "Branch: ${scope}/${topic}" >&2

  echo "${scope}/${topic}"
}

#######################################
# Reads the pull request of a branch.
# Arguments:
#   Branch name.
# Outputs:
#   Writes "<number> <state> <head commit> <url>" to STDOUT.
# Returns:
#   Non-zero when the branch has no pull request.
#######################################
pr_info() {
  gh pr view "$1" --json number,state,headRefOid,url \
    --jq '"\(.number) \(.state) \(.headRefOid) \(.url)"' 2> /dev/null
}

#######################################
# Checks that deleting a branch loses no commits: its local tip, and its
# remote tip if it still exists, must be the head of its pull request or an
# ancestor of it. Rebase merges rewrite commits, so this compares with the
# pull request instead of the default branch.
# Globals:
#   REMOTE
# Arguments:
#   Branch name, pull request number, head commit of the pull request.
# Returns:
#   0 when the branch is safe to delete, 1 otherwise.
#######################################
is_tip_in_pr() {
  local -r branch="$1" number="$2" head="$3"
  local ref tip
  local fetched=false

  for ref in "refs/heads/${branch}" "refs/remotes/${REMOTE}/${branch}"; do
    tip="$(git rev-parse --verify --quiet "${ref}")" || continue
    [[ "${tip}" == "${head}" ]] && continue

    if [[ "${fetched}" == false ]]; then
      git fetch --quiet "${REMOTE}" "pull/${number}/head" 2> /dev/null || true
      fetched=true
    fi
    git merge-base --is-ancestor "${tip}" "${head}" 2> /dev/null || return 1
  done
}

#######################################
# Deletes a branch locally and on the remote, if it still exists there.
# Globals:
#   REMOTE
# Arguments:
#   Branch name.
#######################################
remove_branch() {
  local -r branch="$1"

  if git ls-remote --exit-code --heads "${REMOTE}" "${branch}" > /dev/null; then
    git push "${REMOTE}" --delete "${branch}"
  fi
  git branch -D "${branch}"
}

#######################################
# Brings the local default branch up to date with the remote.
# Globals:
#   REMOTE
# Arguments:
#   Default branch.
#######################################
update_default_branch() {
  local -r base="$1"

  if [[ "$(current_branch)" == "${base}" ]]; then
    git pull --ff-only "${REMOTE}" "${base}"
  elif git show-ref --verify --quiet "refs/heads/${base}"; then
    git fetch "${REMOTE}" "${base}:${base}"
  fi
}

#######################################
# Creates a branch from the latest default branch.
# Globals:
#   REMOTE
# Arguments:
#   Optional branch name.
#######################################
create_branch() {
  local name="${1:-}"
  local base

  require_clean_tree
  if [[ -z "${name}" ]] || ! validate_branch_name "${name}"; then
    if [[ ! -t 0 ]]; then
      [[ -n "${name}" ]] || err "branch name is required"
      exit 1
    fi
    name="$(prompt_branch_name)"
    validate_branch_name "${name}"
  fi

  if git show-ref --verify --quiet "refs/heads/${name}"; then
    err "branch '${name}' already exists"
    exit 1
  fi
  if git ls-remote --exit-code --heads "${REMOTE}" "${name}" > /dev/null; then
    err "branch '${name}' already exists on ${REMOTE}"
    exit 1
  fi

  base="$(default_branch)"
  git fetch "${REMOTE}" "${base}"
  git switch --no-track --create "${name}" "${REMOTE}/${base}"
}

#######################################
# Pushes a branch with upstream and opens its pull request. Uses the commits
# for title and body unless the arguments set them. Refuses the default
# branch, names outside the branch schema (e.g. bot branches) and branches
# whose pull request is already merged or closed. A push that is not a
# fast-forward fails, so commits on the remote are never overwritten.
# Globals:
#   REMOTE
# Arguments:
#   Optional branch name, defaults to the current branch. Arguments after
#   "--" go to `gh pr create`, e.g. --draft.
#######################################
open_pr() {
  local branch="" base info number state head url arg
  local fill="--fill"

  if (( $# > 0 )) && [[ "$1" != "--" ]]; then
    branch="$1"
    shift
  fi
  if (( $# > 0 )) && [[ "$1" == "--" ]]; then
    shift
  fi

  base="$(default_branch)"
  branch="${branch:-$(current_branch)}"
  if [[ -z "${branch}" || "${branch}" == "${base}" ]]; then
    err "name a feature branch or switch to one first"
    exit 1
  fi
  if ! git show-ref --verify --quiet "refs/heads/${branch}"; then
    err "branch '${branch}' does not exist"
    exit 1
  fi
  validate_branch_name "${branch}" || exit 1

  if info="$(pr_info "${branch}")"; then
    read -r number state head url <<< "${info}"
    if [[ "${state}" != OPEN ]]; then
      err "pull request ${url} is already ${state,,}, use delete-branch"
      exit 1
    fi
  fi

  git push --set-upstream "${REMOTE}" "${branch}"

  if [[ "${state:-}" == OPEN ]]; then
    echo "Pull request already open: ${url}"
    return
  fi

  for arg in "$@"; do
    case "${arg}" in
      -t | --title* | -b | --body* | -F | -T | --template* | -f | --fill*) fill="" ;;
    esac
  done
  gh pr create --base "${base}" --head "${branch}" ${fill:+"${fill}"} "$@"
}

#######################################
# Deletes a branch whose pull request is merged or closed and updates the
# default branch.
# Arguments:
#   Optional branch name, defaults to the current branch.
#######################################
delete_branch() {
  local branch="${1:-}"
  local base info number state head url

  base="$(default_branch)"
  branch="${branch:-$(current_branch)}"
  if [[ -z "${branch}" || "${branch}" == "${base}" ]]; then
    err "name a feature branch or switch to one first"
    exit 1
  fi
  if ! git show-ref --verify --quiet "refs/heads/${branch}"; then
    err "branch '${branch}' does not exist"
    exit 1
  fi
  if ! info="$(pr_info "${branch}")"; then
    err "branch '${branch}' has no pull request"
    exit 1
  fi
  read -r number state head url <<< "${info}"

  case "${state}" in
    MERGED) ;;
    CLOSED)
      if ! confirm "Pull request ${url} was closed without merging. Delete '${branch}'?"; then
        echo "Kept '${branch}'."
        return
      fi
      ;;
    *)
      err "pull request ${url} is still ${state,,}"
      exit 1
      ;;
  esac
  if ! is_tip_in_pr "${branch}" "${number}" "${head}"; then
    err "'${branch}' has commits that are not in ${url}, kept it"
    exit 1
  fi

  if [[ "$(current_branch)" == "${branch}" ]]; then
    require_clean_tree
    git switch "${base}"
  fi
  update_default_branch "${base}"
  remove_branch "${branch}"
  git fetch --prune --quiet "${REMOTE}"
}

#######################################
# Deletes the leftovers of merged or closed pull requests, after asking: local
# branches, and branches that only exist on the remote. Skips the current
# branch, branches with commits not in their pull request, branches without a
# pull request and remote names outside the branch schema (e.g. bot branches).
# Globals:
#   REMOTE
#######################################
cleanup_repo() {
  local base current branch info number state head url
  local local_branches=() remote_branches=()

  base="$(default_branch)"
  current="$(current_branch)"
  git fetch --prune --quiet "${REMOTE}"

  while read -r branch; do
    [[ "${branch}" == "${base}" ]] && continue
    info="$(pr_info "${branch}")" || continue
    read -r number state head url <<< "${info}"
    [[ "${state}" == MERGED || "${state}" == CLOSED ]] || continue

    if [[ "${branch}" == "${current}" ]]; then
      echo "Skipped '${branch}': it is checked out, use delete-branch."
    elif ! is_tip_in_pr "${branch}" "${number}" "${head}"; then
      echo "Skipped '${branch}': it has commits that are not in ${url}."
    else
      printf '  %-40s %-6s %-7s %s\n' "${branch}" local "${state,,}" "${url}"
      local_branches+=("${branch}")
    fi
  done < <(git for-each-ref --format='%(refname:lstrip=2)' refs/heads)

  while read -r branch; do
    [[ "${branch}" == "${base}" || "${branch}" == HEAD ]] && continue
    git show-ref --verify --quiet "refs/heads/${branch}" && continue
    validate_branch_name "${branch}" 2> /dev/null || continue
    info="$(pr_info "${branch}")" || continue
    read -r number state head url <<< "${info}"
    [[ "${state}" == MERGED || "${state}" == CLOSED ]] || continue

    if ! is_tip_in_pr "${branch}" "${number}" "${head}"; then
      echo "Skipped remote '${branch}': it has commits that are not in ${url}."
    else
      printf '  %-40s %-6s %-7s %s\n' "${branch}" remote "${state,,}" "${url}"
      remote_branches+=("${branch}")
    fi
  done < <(git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/${REMOTE}")

  if (( ${#local_branches[@]} + ${#remote_branches[@]} == 0 )); then
    echo "No leftover branches."
    return
  fi
  if ! confirm "Delete these $(( ${#local_branches[@]} + ${#remote_branches[@]} )) branches?"; then
    echo "Kept all branches."
    return
  fi

  for branch in "${local_branches[@]}"; do
    remove_branch "${branch}"
  done
  for branch in "${remote_branches[@]}"; do
    git push "${REMOTE}" --delete "${branch}"
  done
  update_default_branch "${base}"
}

main() {
  if (( $# == 0 )); then
    err "${USAGE}"
    exit 1
  fi
  local -r command="$1"
  shift

  if [[ "${command}" == -h || "${command}" == --help ]]; then
    echo "${USAGE}"
    return
  fi
  if ! command -v gh > /dev/null; then
    err "the GitHub CLI (gh) is required, see https://cli.github.com"
    exit 1
  fi
  cd "${ROOT_DIR}"

  case "${command}" in
    create-branch) create_branch "$@" ;;
    open-pr) open_pr "$@" ;;
    delete-branch) delete_branch "$@" ;;
    cleanup-repo) cleanup_repo ;;
    *)
      err "${USAGE}"
      exit 1
      ;;
  esac
}

main "$@"
