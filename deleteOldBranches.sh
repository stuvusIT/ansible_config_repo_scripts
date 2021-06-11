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
DATA_DIR=".git/pushed_branches/"

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

if [ "$includeUnpushed" == "false" ] && ! test -d "$DATA_DIR" ;then
  echo "The dir $DATA_DIR does not exist. It is needed to know which branch was pushed with what commit."
  echo "Please install the apropriate push hook or use --include-unpushed."
  exit 1
fi

git remote prune "$REMOTE_NAME"

while IFS= read -r branch; do
  remoteExists="$(git ls-remote "$REMOTE_NAME" "$branch" | wc -l)"
  if [ "$remoteExists" == "1" ] ;then
    # Remote exists do not delete
    continue
  fi
  if [ "$includeUnpushed" == "false" ] ;then
    if ! test -f "$DATA_DIR/$branch" ;then
      #Was never pushed, do not delete
      continue
    fi
    currentOid="$(git rev-parse "$branch")"
    pushedOid="$(cat "$DATA_DIR/$branch")"
    if [ "$currentOid" != "$pushedOid" ] ;then
      #Current commit is different from last pushed commit, do not delete
      continue
    fi
  fi
  git branch -D "$branch"
done < <(git branch --format '%(refname:lstrip=2)')

