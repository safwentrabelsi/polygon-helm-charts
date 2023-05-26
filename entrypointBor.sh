#!/bin/sh

# exit script on any error
set -e

# Dowloand tools
apk add --no-cache ca-certificates curl jq zstd pv aria2 tar

# Set Bor Home Directory
BOR_HOME=/home/bor

# set client
client=bor

# set snapshot url
SNAPSHOT_URL=https://snapshot-download.polygon.technology/${client}-${NETWORK}-incremental-compiled-files.txt

# set extracted files directory
extract_dir=/bor/chaindata

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
touch ${BOR_HOME}/bootstrapped

}

# Check for genesis file and download or update it if needed
if [ ! -f "${BOR_HOME}/genesis.json" ];
then
    echo "setting up initial configurations"
    cd ${BOR_HOME}
    echo "downloading launch genesis file"
    wget -O genesis.json https://raw.githubusercontent.com/maticnetwork/bor/master/builder/files/genesis-mainnet-v1.json
    echo "initializing bor with genesis file"
    bor --datadir ${BOR_HOME} init ${BOR_HOME}/genesis.json
fi

if [ "${BOOTSTRAP}" == 1 ]  && [ ! -f "${BOR_HOME}/bootstrapped" ];
then
  echo "downloading snapshot from ${SNAPSHOT_URL}"
  mkdir -p ${BOR_HOME}/${extract_dir}
  aria2c -x6 -s6 "${SNAPSHOT_URL}" 
  aria2c -x6 -s6 -i "${client}-${NETWORK}-incremental-compiled-files.txt"
  echo "extracting files into ${extract_dir}"
  extract_files "${client}-${NETWORK}-incremental-compiled-files.txt"
fi


READY=$(curl -s http://localhost:26657/status | jq '.result.sync_info.catching_up')
while [[ "${READY}" != "false" ]];
do
    echo "Waiting for heimdalld to catch up."
    sleep 30
    READY=$(curl -s localhost:26657/status | jq '.result.sync_info.catching_up')
done

exec bor server --port=40303 --maxpeers=${MAXPEERS:-200} --datadir=${BOR_HOME} --syncmode=full \
    --ipcpath ${BOR_HOME}/bor.ipc --bor.heimdall=http://localhost:1317 \
    --http --http.addr=0.0.0.0 --http.port=8545 --http.api=admin,debug,eth,net,web3,txpool,bor --http.corsdomain="*" --http.vhosts="*"  \
    --ws --ws.addr=0.0.0.0 --ws.port=8545 --ws.api=admin,debug,eth,net,web3,txpool,bor --ws.origins="*" -bootnodes ""enode://0cb82b395094ee4a2915e9714894627de9ed8498fb881cec6db7c65e8b9a5bd7f2f25cc84e71e89d0947e51c76e85d0847de848c7782b13c0255247a6758178c@44.232.55.71:30303", "enode://88116f4295f5a31538ae409e4d44ad40d22e44ee9342869e7d68bdec55b0f83c1530355ce8b41fbec0928a7d75a5745d528450d30aec92066ab6ba1ee351d710@159.203.9.164:30303""
