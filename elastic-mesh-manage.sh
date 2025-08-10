#!/bin/bash
# Usage: ./elastic-mesh-manage.sh cmd x (where cmd is the docker compose command, e.g. up, down, restart, x is the cluster number, e.g. 01, y is the optional end cluster, e.g. 08 will run the command against clusters 01-08 )

if [[ "$#" -ne 2 && "$#" -ne 3 ]]; then
    echo 'Usage: ./elastic-mesh-manage.sh cmd x (where cmd is the docker compose command, e.g. up, down, restart, x is the cluster number, e.g. 01, y is the end of cluster from the start cluster, e.g. 08 will run the command against clusters 01-08 )'
    exit 0
fi

printf -v clusterNum "%02d" $3

if [ -z "$3" ]
  then
    clusterNum = 1
fi

declare cmd
if [[ "$1" == "up" ]]; then
	cmd="up -d"
else
	cmd=$1
fi

elasticPassword=""
kibanaPassword=""
enryptionKey=""
elasticUID=$(id -u elastic)

baseDir="/mnt/data/mesh"
credsFile="$baseDir/credentials.txt"

# Assume the creds file exists (as we've already creatded the clusters)
elasticPassword=$(grep elastic $credsFile | awk -F= '{print $2}')
kibanaPassword=$(grep kibana_system $credsFile | awk -F= '{print $2}')
encryptionKey=$(grep kibana_encryption_key $credsFile | awk -F= '{print $2}')

export ENCRYPTION_KEY=$encryptionKey # Not used but needed as it's in the docker compose file
export ELASTIC_MEM_LIMIT="2g"
export ELASTIC_PASSWORD=$elasticPassword
export ELASTIC_UID=$elasticUID
export KIBANA_MEM_LIMIT="2g"
export KIBANA_PASSWORD=$kibanaPassword
export STACK_VERSION=8.18.1

for ((x="$2"; x<="$clusterNum"; x++)); do
# Cast the loop counter to a string with leading zero if needed:
	declare instance=""
	printf -v instance "%02d" $x;
# Run envsubst to substitute the instance Id in the docker compose template file and pipe the result via stdin to docker compose with the relevant command:
	export instance=$instance && envsubst < /opt/elastic-data-mesh/docker-compose-mesh-node.yml | docker compose -p mesh-cluster$instance -f - $cmd
done;
