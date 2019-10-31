#!/bin/bash

set -eo pipefail

data_dir=""
if [[ "$OSTYPE" =~ ^darwin ]]; then
    # we're on macOS
    data_dir="$HOME/Library/Application Support/BLOCS"
else
    data_dir="$HOME/.blocs"
fi

ssh_username="root"
vps_setup_url="./vps-setup.sh"
collateral_amount=3000
ip_pubkey_db="$HOME/.blocs-masternode-list"
mn_wait_threshold=$((25 * 60))
pending_activations_list="$HOME/.blocs-pending-activation-list"

ips=()

function is_osx() {
  [[ "$OSTYPE" =~ ^darwin ]] || return 1
}

main() {
    # get the list of IP addresses
    if [[ -f "$1" ]]; then
        # read from the $1
        while read -r line; do
            ips+=("$line")
        done < "$1"
    else
        # assume all the arguments are the list of ips
        while [[ "$1" ]]; do
            ips+=("$1")
            shift
        done
    fi

    index=0
    # fetch the last masternode's index
    line=$(tail -n1 "$data_dir"/masternode.conf | cut -d ' ' -f 1 || true)
    re='^mn[0-9]+$'
    if [[ "$line" =~ $re ]]; then
        index=$(echo $line | tail -c +3)
    fi

    for ip in "${ips[@]}"; do
        ((index++)) || true
        mn_name="mn$index"

        # run the setup script on the VPS
        echo "Running the setup script on the remote VPS."
        #cat "$vps_setup_url" | ssh -o StrictHostKeyChecking=no "${ssh_username}@${ip}"

        # unlock the local wallet
        if [[ ! -z "$BLOCS_WALLET_PASSPHRASE" ]]; then
            blocs-cli walletpassphrase "$BLOCS_WALLET_PASSPHRASE" 0 false
        fi

        # generate masternode's private key and create a collateral transaction
        mn_priv_key=$(blocs-cli createmasternodekey)
        pub_key=$(blocs-cli getaccountaddress "$mn_name")
        echo "Generating the collateral transaction."
        mn_tx_hash=$(blocs-cli sendtoaddress "$pub_key" $collateral_amount)

        # stop till the transaction has been included in a block
        echo "Waiting for the collateral transaction to be included in a block..."
        until grep -qs '"blockhash"' <(blocs-cli gettransaction "$mn_tx_hash"); do
            echo "Transaction not included in the blockchain."
            for (( i=15; i > 0; i-- )); do
                    echo -en "\rRechecking in $i seconds"
                    sleep 1
            done
            echo
        done

        echo "Transaction has now been confirmed!"

        # get the vout index (default to 1, check if it's 0)
        vout_index=1
        if blocs-cli gettxout "$mn_tx_hash" 0 | grep -qs '"value": '"${collateral_amount}.0"; then
            vout_index=0
        fi

        # update the masternode.conf file and restart the daemon
        echo "Updating the local masternode.conf file"
        blocs-cli stop
        echo "$mn_name ${ip}:5636 $mn_priv_key $mn_tx_hash $vout_index" >> "$data_dir"/masternode.conf
        blocsd -daemon
        echo "Waiting for the daemon to start up."
        for (( i=10; i > 0; i-- )); do
                echo -en "\rResuming in $i seconds"
                sleep 1
        done
        echo

        # again, unlock the wallet
        if [[ ! -z "$BTST_WALLET_PASSPHRASE" ]]; then
            blocs-cli walletpassphrase "$BTST_WALLET_PASSPHRASE" 0 false || true
        fi


        # update blocs.conf on the vps
        echo "Updating blocs.conf on the remote VPS..."
        ssh -o StrictHostKeyChecking=no "${ssh_username}@${ip}" '
            blocs-cli stop
            echo -e "masternode=1\nmasternodeaddr='"${ip}"':5636\nmasternodeprivkey='"${mn_priv_key}"'" >> .blocs/blocs.conf
            blocsd -daemon >/dev/null 2>&1
            echo "Waiting for the remote daemon to start up."
            for (( i=10; i > 0; i-- )); do
                    echo -en "\rResuming in $i seconds"
                    sleep 1
            done
            echo
        '

        hotnode_started="false"
        elapsed=0

        while [[ "$hotnode_started" == "false" ]]; do
            # start masternode from the controller
            output="$(blocs-cli startmasternode alias false $mn_name)"
            echo "$output"
            grep -qs 'Successfully started 1 masternode' <(echo "$output")

            # start the hot node (vps)
            ssh -o StrictHostKeyChecking=no "${ssh_username}@${ip}" '
                blocs-cli startmasternode local false | grep -qs "Masternode successfully started"
            ' && hotnode_started="true" && break || hotnode_started="false"

            if [[ "$elapsed" -ge "$mn_wait_threshold" ]]; then
                echo "There seems to be some issue. Hot node (VPS) failed to activate after $mn_wait_threshold seconds"
                break
            fi

            echo "Hot node (VPS) not ready after waiting for $elapsed seconds."
            for (( i=30; i > 0; i-- )); do
                    echo -en "\rRetrying in $i seconds"
                    sleep 1
            done
            echo
            ((elapsed += 30)) || true
        done

        if [[ "$hotnode_started" == "false" ]]; then
            echo "Failed to start the hot node (VPS). Adding it to $pending_activations_list." >&2
            echo "$ip" >> "$pending_activations_list"
        fi

        # write IP address, public key to the file
        echo "${ip},${pub_key}" >> "$ip_pubkey_db"
    done
}

main "$@"

