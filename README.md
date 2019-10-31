# blocs-mn-scripts
Scripts that facilitate an easy setup of blocs masternodes  

## Prerequisite
* 3000 BLOCS.
* A main Linux computer(Your everyday computer) / Controlling Wallet.
* Masternode Server(The computer that will be on 24/7).
* A unique static Public IP address for EACH masternode.

## Controller-setup.sh
Following script runs on controlling wallet node and it helps in automating the process of creating and activating masternode.

**Note**
1. In case your remote system's username is not root then change `ssh_username` variable in the script as per actual system username.

2. In case your datadir is different then default datadir then change the `data_dir` variable in the script.

3. In case you use ssh Identity file authenciation where you have **privkeyname.pem** file for accessing remote vps which are masternode in this case, then create **config** file in `~/.ssh/`  and add following to it.
`IdentityFile path/to/privkey/privkeyname.pem`
There can be multiple Identity files added to it.

## Steps to follow
Following commands are to be runned on controlling wallet.

1. This will download dxr-mn-script to your controlling wallet.
`git clone https://github.com/blockanalysis/blocs-mn-scripts.git`
2. cd blocs-mn-scripts
3. Before running the script please read the **Note** section below.
Running the script 
```bash
./controller-setup.sh [arguments]
```

### Different ways of running script

**Note**
If wallet is encrypted then declare an environment variable named as BLOCS_WALLET_PASSPHRASE="abcd" where "abcd" is your passphrase.  

Example of such command is here.
```bash
unset HISTFILE
BLOCS_WALLET_PASSPHRASE="abcd" ./controller-setup.sh [arguments]
```

controller-setup.sh script can take input of masternode ip address as arguement in one of the following ways.

1. Passing each masternode ip as separate arguements.   
Example: 
```bash
./controller-setup.sh ip1 ip2 ip3 
```

2. Passing a filename which contains list of masternode ip address(one ip address per line)   
Example: 
```bash
./controller-setup.sh <filename>
```

After the script successfully executes following files are added to users home directory     
* .blocs-masternode-list which keeps a record of all masternode ip address and respective public keys.
* .blocs-pending-activation-list which keeps a record of all masternode ip address which could not be activated post 15 minite of running of script due to hotnode activation errors. These nodes should be activated by user manually. 
