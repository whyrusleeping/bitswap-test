#!/bin/bash

export IPTB_ROOT=$(pwd)/testbed

NUMNODES=5

runtitle="$1"

iptb init -f -n $NUMNODES --type=docker

iptb for-each ipfs config --json Datastore.NoSync true

iptb start

echo "nodes started"

ipfsi() {
	local n=$1
	shift
	IPFS_PATH=$IPTB_ROOT/$n ipfs $@
}

sudo -E iptb set latency 10ms '[0-4]'

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

/bin/time -f "%E" iptb run 1 ipfs pin add $HASH 2> time_1
/bin/time -f "%E" iptb run 2 ipfs pin add $HASH 2> time_2
/bin/time -f "%E" iptb run 3 ipfs pin add $HASH 2> time_3
/bin/time -f "%E" iptb run 4 ipfs pin add $HASH 2> time_4

dup1=$(iptb run 1 ipfs bitswap stat --enc=json | jq .DupBlksReceived)
dup2=$(iptb run 2 ipfs bitswap stat --enc=json | jq .DupBlksReceived)
dup3=$(iptb run 3 ipfs bitswap stat --enc=json | jq .DupBlksReceived)
dup4=$(iptb run 4 ipfs bitswap stat --enc=json | jq .DupBlksReceived)

totalblocks=$(iptb run 0 ipfs refs -r $HASH | wc -l)

echo $runtitle $totalblocks $dup1 $dup2 $dup3 $dup4
printf "%s,%s,%s,%s,%s,%s," $runtitle $totalblocks $dup1 $dup2 $dup3 $dup4 >> results.csv
printf "%s,%s,%s,%s\n" $(cat time_1) $(cat time_2) $(cat time_3) $(cat time_4) >> results.csv
iptb kill
