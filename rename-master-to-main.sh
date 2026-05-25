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
DELETE_MASTER=false
if [ "${2:-}" = "--delete-master" ]; then
  DELETE_MASTER=true
fi

DRY_RUN="${DRY_RUN:-0}"

echo "Owner: $OWNER"
echo "Delete master after rename: $DELETE_MASTER"
echo "Dry run: $DRY_RUN"

# Get list of repos for owner
repos=$(gh repo list "$OWNER" --limit 1000 --json name -q '.[].name')

for repo in $repos; do
  echo "-----"
  echo "Processing repo: $OWNER/$repo"

  # Check if master branch exists
  if gh api --silent "/repos/$OWNER/$repo/branches/master" >/dev/null 2>&1; then
    echo "master branch exists."

    # Get master SHA
    master_sha=$(gh api "/repos/$OWNER/$repo/git/ref/heads/master" --jq '.object.sha')
    echo "master SHA: $master_sha"

    # Check if main already exists
    if gh api --silent "/repos/$OWNER/$repo/branches/main" >/dev/null 2>&1; then
      echo "main branch already exists in $repo — skipping creation."
    else
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would create refs/heads/main with sha $master_sha"
      else
        echo "Creating refs/heads/main..."
        gh api -X POST "/repos/$OWNER/$repo/git/refs" -f ref="refs/heads/main" -f sha="$master_sha"
        echo "Created main."
      fi
    fi

    # Set default branch to main
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[DRY RUN] Would set default branch to main for $OWNER/$repo"
    else
      echo "Setting default branch to main..."
      gh repo edit "$OWNER/$repo" --default-branch main
      echo "Default branch set to main."
    fi

    # Optional: delete master
    if [ "$DELETE_MASTER" = true ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would delete branch refs/heads/master"
      else
        echo "Deleting master branch..."
        gh api -X DELETE "/repos/$OWNER/$repo/git/refs/heads/master"
        echo "Deleted master."
      fi
    else
      echo "Not deleting master (pass --delete-master to delete)."
    fi

  else
    echo "No master branch in $repo — skipping."
  fi
done
