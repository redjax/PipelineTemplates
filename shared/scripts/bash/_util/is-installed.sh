#!/usr/bin/env bash
set -uo pipefail

##################################################################################
# Utility script to check if a command is available in the shell.                #
#                                                                                #
# The script can be called directly, i.e.:                                       #
#   bash pipelinetemplates/shared/scripts/bash/_util/is-installed.sh <some-cmd>  #
#                                                                                #
# Or by sourcing it and running later, i.e.:                                     #
#   . pipelinetemplates/shared/script/bash/_util/is-installed.sh                 #
#   is_installed curl || exit 1                                                  #
#                                                                                #
# Returns 0 if available, 1 otherwise                                            #
##################################################################################

is_installed() {
  local cmd="$1"
  [[ -z "$cmd" ]] && return 1
  command -v "$cmd" >/dev/null 2>&1
}

## If script is called directly, run is_installed with $1
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  is_installed "$1"
fi
