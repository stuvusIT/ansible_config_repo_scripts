#!/usr/bin/env bash

# This script allows to delete old git branches
# To determine what branches are old, two criteria are used:
# 1. Which branches exist at the remote called origin
# 2. Which branches have unpushed commits

function printUsage() {
  echo "Usage:"
  echo "$0 [options]"
  echo ""
  echo "Possible options:"
  echo "-h --help               Print this help"
  echo "   --include-unpushed   Include unpushed branches"
}

REMOTE_NAME="origin"

TMP_REMOTE_TRACKING_OIDS=".git/.deletetOldBranches_remote_tracking_oids/"

includeUnpushed="false"

if [ $# -gt 0 ] ;then
  for var in "$@" ;do
    if [ "$var" == "-h" ] || [ "$var" == "--help" ] ;then
      printUsage
      exit 0
    elif [ "$var" == "--include-unpushed" ] ;then
      includeUnpushed="true"
    else
      printUsage
      exit 2
    fi
  done
fi

default_branch="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/'"$REMOTE_NAME"'/@@')"

# Store which branches were pushed/fetched with which oid
rm -rf "$TMP_REMOTE_TRACKING_OIDS"
while IFS= read -r branch; do
  if upstream=$(git rev-parse "$branch@{u}" 2>/dev/null); then
    mkdir --parents "$(dirname "$TMP_REMOTE_TRACKING_OIDS/$branch")"
    echo "$upstream" > "$TMP_REMOTE_TRACKING_OIDS/$branch"
  fi
done < <(git branch --format '%(refname:lstrip=2)')

# Delete all the origin/xyz branches
git remote prune "$REMOTE_NAME"

# Delete all the branches git can itself detect that they are merged.
# These include branches that were merged without rebase or squash and branches without any commit made on them
while IFS= read -r branch; do
  if [ "$branch" == "$default_branch" ] ;then 
    # Don't delete the default branch
    continue
  fi
  git branch -d "$branch"
done < <(git branch --format '%(refname:lstrip=2)' --merged)

# Delete all branches where we do not find a reason to keep

while IFS= read -r branch; do
  remoteExists="$(git ls-remote "$REMOTE_NAME" "$branch" | wc -l)"
  if [ "$remoteExists" == "1" ] ;then
    # Remote exists do not delete
    continue
  fi
  if [ "$includeUnpushed" == "false" ] ;then
    if ! test -f "$TMP_REMOTE_TRACKING_OIDS/$branch" ;then
      #Was never pushed, do not delete
      continue
    fi
    currentOid="$(git rev-parse "$branch")"
    pushedOid="$(cat "$TMP_REMOTE_TRACKING_OIDS/$branch")"
    if [ "$currentOid" != "$pushedOid" ] ;then
      #Current commit is different from last pushed commit, do not delete
      continue
    fi
  fi
  git branch -D "$branch"
done < <(git branch --format '%(refname:lstrip=2)')
