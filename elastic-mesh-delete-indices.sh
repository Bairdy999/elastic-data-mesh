#!/bin/bash

# Set environment variables as follows before running this script:
# Standalone cluster:
#   export ELASTICSEARCH_URL="elastic endpoint"
# 	export ELASTIC_API_KEY="elastic-api-key"
# Mesh clusters:
#   export ELASTIC_MESH_HOST="mesh base host"
#   export ELASTIC_MESH_PASSWORD="elastic user password"

# For mesh deployment run: 'elastic-mesh-delete-indices.sh mesh xx' where xx is the number of clusters to delete the index in

# source .env <-- loads and exports env vars but doesn't substitute correctly


if [[ "$1" == "mesh" ]]; then
	export CLUSTER_COUNT=$2

	for ((x=1; x<="$2"; x++)); do
# First cast the loop counter to a string with leading zero if needed:
		echo ""
		declare instance=""
		printf -v instance "%02d" $x;
		declare elasticUrl="$ELASTIC_MESH_HOST/cluster$instance/elastic"

		echo "Deleting pole-data index in cluster $x"
		curl -s -k -H "Content-Type: application/json" -X DELETE -u "elastic:$ELASTIC_MESH_PASSWORD" "https://cluster$instance-elastic:9200/pole-data"
	done;

else

	curl -k -X DELETE -H "Authorization: ApiKey $ELASTIC_API_KEY" -H "Content-Type: application/json" "${ELASTICSEARCH_URL}/pole-data"

fi
