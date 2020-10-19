#!/bin/sh

cd `dirname "$0"`

if [ ! -f "tracker-profile.sh" ]; then
	echo "tracker-profile.sh not found in `pwd`! " >&2
	if [ -z "$CRS_TRACKER" -o -z "$CRS_TOKEN" -o -z "$CRS_SECRET" ]; then
		echo 'Env vars CRS_TRACKER, CRS_TOKEN or CRS_SECRET are also empty.' >&2
		echo 'Please create tracker-profile.sh or define env vars!' >&2
		exit 1
	fi
fi

screen -c ./screenrc-encoding-only
