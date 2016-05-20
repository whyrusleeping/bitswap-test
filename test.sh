#!/bin/bash

export IPTB_ROOT=$(pwd)/testbed

NUMNODES=5

runtitle="$1"

iptb init -f -n $NUMNODES

iptb start

ipfsi() {
	local n=$1
	shift
	IPFS_PATH=$IPTB_ROOT/$n ipfs $@
}

fixcfg() {
	ipfsi $1 config --json Datastore.NoSync true
}

fixcfg 0
fixcfg 1
fixcfg 2
fixcfg 3
fixcfg 4

echo "connecting nodes..."

iptb connect 0 1
iptb connect 0 2
iptb connect 0 3
iptb connect 0 4

echo "creating random files..."

rm -rf stuff
random-files -depth=3 -dirs=6 -files=10 stuff > /dev/null

echo "adding files on node 0..."

HASH=$(ipfsi 0 add -r -q stuff | tail -n 1)

echo "Added content: $HASH"

ipfsi 1 pin add $HASH
ipfsi 2 pin add $HASH
ipfsi 3 pin add $HASH
ipfsi 4 pin add $HASH

dup1=$(ipfsi 1 bitswap stat --enc=json | jq .DupBlksReceived)
dup2=$(ipfsi 2 bitswap stat --enc=json | jq .DupBlksReceived)
dup3=$(ipfsi 3 bitswap stat --enc=json | jq .DupBlksReceived)
dup4=$(ipfsi 4 bitswap stat --enc=json | jq .DupBlksReceived)

totalblocks=$(ipfsi 0 refs -r $HASH | wc -l)

echo $runtitle $totalblocks $dup1 $dup2 $dup3 $dup4
printf "%s,%s,%s,%s,%s,%s\n" $runtitle $totalblocks $dup1 $dup2 $dup3 $dup4 >> results.csv
iptb kill
