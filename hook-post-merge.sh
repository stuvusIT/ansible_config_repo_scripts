#!/usr/bin/env bash

# Hook that is run by git after merging (e.g. after a git pull)

git submodule update --init --recursive -j 8
