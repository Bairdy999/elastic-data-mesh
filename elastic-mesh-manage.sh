#!/bin/bash
# Usage: ./elastic-mesh-manage.sh cmd x (where cmd is the docker compose command, e.g. up, down, restart, and x is the cluster number, e.g. 01 )

if [[ "$#" -eq 0 || "$#" -ne 2 ]]; then
    echo 'Usage: ./elastic-mesh-manage.sh cmd x (where cmd is the docker compose command, e.g. up, down, restart, and x is the cluster number, e.g. 01 )'
    exit 0
fi

# First cast the instance number to a string with leading zero if needed:
printf -v instance "%02d" $2

declare cmd
if [[ "$1" == "up" ]]; then
	cmd="up -d"
else
	cmd=$1
fi

elasticUID=$(id -u elastic)

export ENCRYPTION_KEY=c34d38b3a14956121ff2170e5030b471551370178f43e5626eec58b04a30fae2 # Not used but needed as it's in the docker compose file
export ELASTIC_MEM_LIMIT="2g"
export ELASTIC_PASSWORD=changeme
export ELASTIC_UID=$elasticUID
export KIBANAB_MEM_LIMIT="2g"
export KIBANA_PASSWORD=changeme
export STACK_VERSION=8.18.1

# Run envsubst to substitute the instance Id in the docker compose template file and pipe the result via stdin to docker compose with the relevant command:
export instance=$instance && envsubst < /opt/elastic-data-mesh/docker-compose-mesh-node.yml | docker compose -p mesh-cluster$instance -f - $cmd
