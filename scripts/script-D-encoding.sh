#!/bin/bash

BASEDIR=$(dirname $(dirname $0))

MASTER_DIR=$BASEDIR/../job-control
MASTER_FILE=master.pl

if ! cd "$MASTER_DIR"; then
    echo "Cannot chdir to $MASTER_DIR" >&2
    exit 1
fi
pwd

if ! test -f "$MASTER_FILE"; then
    echo "$MASTER_FILE disappeared" >&2
    exit 1
fi

perl "$MASTER_FILE" "" "$$"
exit $?
