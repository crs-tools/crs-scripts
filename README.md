# CRS Worker scripts

This repository contains a set of worker scripts that communicate with the 
https://github.com/crs-tools/tracker , which are used in production.

For other people this can serve as a starting point for developing or forking their own custom scripts.

## Script checks

Before executing the script, `bin/crs_run` will execute checks found in the folder that is specified by `CHECK_DIR`. If the exit code is not equal to `0`, `crs_run` will exit with the exit code from the check. If the check exits with `0`, it will consider it successful and proceed with running the script.
