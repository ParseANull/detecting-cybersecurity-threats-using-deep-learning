#!/usr/bin/env bash
set -euo pipefail

# rename-master-to-main.sh
# Usage:
# DRY_RUN=1 ./rename-master-to-main.sh ParseANull --delete-master
# Example: DRY_RUN=1 ./rename-master-to-main.sh ParseANull

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <owner> [--delete-master]"
  exit 1
fi

OWNER="$1"
DELETE_MASTER=0
if [ "${2:-}" = "--delete-master" ]; then
  DELETE_MASTER=1
elif [ "${2:-}" != "" ]; then
  echo "Unknown option: ${2}"
  echo "Usage: $0 <owner> [--delete-master]"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required."
  exit 1
fi

REPO_NAME="$(basename "$(git rev-parse --show-toplevel)")"
REPO_SLUG="${OWNER}/${REPO_NAME}"
DRY_RUN="${DRY_RUN:-0}"

run_cmd() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY_RUN] $*"
  else
    eval "$@"
  fi
}

echo "Repository: ${REPO_SLUG}"

if [ "$DRY_RUN" = "1" ]; then
  default_branch="${DEFAULT_BRANCH:-master}"
  echo "[DRY_RUN] gh repo view \"${REPO_SLUG}\" --json defaultBranchRef -q .defaultBranchRef.name"
else
  default_branch="$(gh repo view "${REPO_SLUG}" --json defaultBranchRef -q .defaultBranchRef.name)"
fi
if [ "$default_branch" = "main" ]; then
  echo "Default branch is already 'main'. Nothing to rename."
else
  if [ "$default_branch" != "master" ]; then
    echo "Default branch is '${default_branch}', not 'master'. Aborting for safety."
    exit 1
  fi

  echo "Renaming default branch 'master' -> 'main'"
  run_cmd "gh api -X POST repos/${REPO_SLUG}/branches/master/rename -f new_name=main"
fi

if [ "$DELETE_MASTER" = "1" ]; then
  echo "Deleting remote 'master' branch"
  run_cmd "gh api -X DELETE repos/${REPO_SLUG}/git/refs/heads/master"
fi

echo "Done."
