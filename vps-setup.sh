#!/bin/bash

###################################################################################
## This script should be run on the VPS that will actually run as the masternode ##
###################################################################################

set -eo pipefail

#dxr_bin_url="https://github.com/dexergiproject/dexergi/releases/download/v1.2.0/dexergi-1.2.0-x86_64-linux-gnu.tar.gz"
install_dir="/usr/local"

main() {
    # check if binaries already exist
    if  ! [[ -x $(command -v blocs-cli) && -x $(command -v blocsd) ]]; then
        # at least one of the binaries is not available, so we'll install all of them
        if [[ -z "$dxr_bin_url" ]]; then
            echo "URL to dexergi binaries is empty!" >&2
            return 1
        fi

        # fetch the and extract the dexergi binaries
	if [[ $UID -ne 0 ]]; then
		# non-root user
		curl -fL "$dxr_bin_url" | sudo tar -xzC "$install_dir" --strip-components=1
	else
		# root user
		curl -fL "$dxr_bin_url" | tar -xzC "$install_dir" --strip-components=1
	fi
    fi

    blocsd -daemon >/dev/null 2>&1
}

main "$@"
