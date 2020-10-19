#!/bin/bash

SCRIPT_NAME=restore-fuse-mounts.pl

# get path
SCRIPT_PATH=$(readlink $0)
if [ $? -eq 0 ]; then
    SCRIPT_PATH=$(dirname ${SCRIPT_PATH})
else
    SCRIPT_PATH=$(dirname $0)
fi
SCRIPT_PATH=$(dirname ${SCRIPT_PATH})

if [ -z "${CRS_SECRET}" ]; then
    if [ -r "${SCRIPT_PATH}/tracker-profile.sh" ] ; then
        . "${SCRIPT_PATH}/tracker-profile.sh"
    fi
    if [ -z "${CRS_SECRET}" ]; then
        echo "CRS_SECRET not set. aborting.";
        exit 1;
    fi
fi

# set perl include path
export PERL5LIB=${SCRIPT_PATH}/lib

# assemble script command
SCRIPT=${SCRIPT_PATH}/scripts/${SCRIPT_NAME}

if [ ! -f "${SCRIPT}" ]; then
    echo "selected script (${SCRIPT}) does not exist";
fi

"${SCRIPT}" $@ 

