#!/bin/sh

# exit script on any error
set -e

# Dowloand tools
apk add --no-cache ca-certificates curl jq zstd pv aria2 tar

# Set Heimdall Home Directory
HEIMDALLD_HOME=/home/heimdall

# set client
client=heimdall

# set snapshot url
SNAPSHOT_URL=https://snapshot-download.polygon.technology/${client}-${NETWORK}-incremental-compiled-files.txt

# set extracted files directory
extract_dir=/data

function extract_files() {
compiled_files=$1
while read -r line; do
if [[ "$line" == checksum* ]]; then
continue
fi
filename=`echo $line | awk -F/ '{print $NF}'`
if echo "$filename" | grep -q "bulk"; then
pv $filename | tar -I zstd -xf - -C ./$extract_dir && rm $filename
else
pv $filename | tar -I zstd -xf - -C ./$extract_dir --strip-components=3 && rm $filename
fi
done < $compiled_files
touch ${HEIMDALLD_HOME}/bootstrapped
}



# If heimdalld container and config file is missing, we need to init and configure it
if [ ! -n "$REST_SERVER" ] && [ ! -f "$HEIMDALLD_HOME/config/config.toml" ] && [ ! -f "$HEIMDALLD_HOME/config/heimdall-config.toml" ];
then
    echo "setting up initial configurations"
    heimdalld init --home=$HEIMDALLD_HOME
    cd $HEIMDALLD_HOME/config

    echo "removing autogenerated genesis file"
    rm genesis.json

    echo "downloading launch genesis file"
    wget -O genesis.json https://raw.githubusercontent.com/maticnetwork/heimdall/master/builder/files/genesis-mainnet-v1.json

        

    echo "overwriting toml config lines"
    # config.toml
    # CORS
    sed -i "s#^cors_allowed_origins.*#cors_allowed_origins = [\"*\"]#" config.toml
    # SEEDS
    sed -i "s#^seeds.*#seeds = \"${BOOTNODES:-"f4f605d60b8ffaaf15240564e58a81103510631c@159.203.9.164:26656,4fb1bc820088764a564d4f66bba1963d47d82329@44.232.55.71:26656,2eadba4be3ce47ac8db0a3538cb923b57b41c927@35.199.4.13:26656,3b23b20017a6f348d329c102ddc0088f0a10a444@35.221.13.28:26656,25f5f65a09c56e9f1d2d90618aa70cd358aa68da@35.230.116.151:26656"}\"#" config.toml
    # heimdall-config.toml
    # BOR
    sed -i "s#^bor_rpc_url.*#bor_rpc_url = \"http://localhost:8545\"#" heimdall-config.toml
    # ETH
    sed -i "s#^eth_rpc_url.*#eth_rpc_url = \"${ETH_RPC_URL}\"#" heimdall-config.toml

fi
# If heimdalld container and we need to bootstrap on first run then download the snapshot
if [ ! -n "$REST_SERVER" ] && [ "${BOOTSTRAP}" == 1 ]  && [ ! -f "$HEIMDALLD_HOME/bootstrapped" ];
then
  cd ${HEIMDALLD_HOME}
  echo "downloading snapshot from ${SNAPSHOT_URL}"
  mkdir -p ${HEIMDALLD_HOME}/${extract_dir}
  aria2c -x6 -s6 "${SNAPSHOT_URL}" 
  aria2c -x6 -s6 -i "${client}-${NETWORK}-incremental-compiled-files.txt"
  echo "extracting files into ${extract_dir}"
  extract_files "${client}-${NETWORK}-incremental-compiled-files.txt"
  
fi

# Run the correct commands for heimdalld or heimdallr containers
if [ -n "$REST_SERVER" ];
then
  EXEC="heimdalld rest-server --chain-id=137 --laddr=tcp://0.0.0.0:1317 --max-open=1000 --node=tcp://localhost:26657 --trust-node=true --home=/${HEIMDALLD_HOME}"
else
  EXEC="heimdalld start --moniker=${MONIKER:-DAPPNodler} --fast_sync --p2p.laddr=tcp://0.0.0.0:26656 --p2p.upnp=false --pruning=syncable --rpc.laddr=tcp://0.0.0.0:26657 --home=/${HEIMDALLD_HOME}"
fi

exec ${EXEC}



