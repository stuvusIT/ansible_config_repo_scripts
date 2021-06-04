#!/usr/bin/env bash

# This hooks stores, what the last pushed commit for each branch is

DATA_DIR=".git/pushed_branches"

while read local_ref local_oid remote_ref remote_oid
do
  branch_name="${local_ref#refs/heads/}"
  mkdir --parents "$(dirname "$DATA_DIR/$branch_name")"

  echo "$local_oid" > "$DATA_DIR/$branch_name"
done
