#!/bin/bash

# only run once per host
#PIDFILE=/var/run/encode-master.pid
#if test -f "$PIDFILE"; then
#    PID="$(cat "$PIDFILE")"
#    if ps -p $PID | grep --quiet 'run\.sh'; then
#        echo Already running >&2
#    #   exit 1
#    fi
#fi
#PID=$$

BASEDIR=$(dirname $(dirname $0))

MASTER_DIR=$BASEDIR/../job-control
MASTER_FILE=master.pl

source "$MASTER_DIR/setvars.sh"

#bash "$MASTER_DIR/rename_encoder.sh"

# ugly hotfix against glusterFS fuckups (remount thingy)
#fusermount -u /c3mnt
#mkdir -p /c3mnt
#sleep 2
#if ! `mount | grep -q c3mnt`; then
#    glusterfs -s 10.26.0.7 /c3mnt
#else
#    fusermount -u /c3mnt && sleep 5 && glusterfs -s 10.26.0.7 /c3mnt
#fi

if ! cd "$MASTER_DIR"; then
    echo "Cannot chdir to $MASTER_DIR" >&2
    exit 1
fi
pwd

if ! test -f "$MASTER_FILE"; then
    echo "$MASTER_FILE disappeared" >&2
    exit 1
fi

#while true; do
    perl "$MASTER_FILE" "$CRS_TOKEN" "$CRS_SECRET" "postencoding" "$$"
    exit $?
#    # exit code 82 means: I want to be restarted
#    if test "$?" -ne 82; then
#        # we are done otherwise (on successful regular execution and on bugs)
#        echo Master exited.
#        exit 1
#    fi
#    sleep 1
#    echo Restarting master ...
#done
