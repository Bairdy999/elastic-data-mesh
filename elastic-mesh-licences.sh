#!/bin/bash

# Set environment variables as follows before running this script:
# Standalone cluster:
#   export ELASTICSEARCH_URL="elastic endpoint"
# 	export ELASTIC_API_KEY="elastic-api-key"
# Mesh clusters:
#   export ELASTIC_MESH_HOST="mesh base host"
#   export ELASTIC_MESH_PASSWORD="elastic user password"

# For mesh deployment run: 'elastic-mesh-licences.sh mesh xx' where xx is the number of clusters to deploy to

# source .env <-- loads and exports env vars but doesn't substitute correctly


if [[ "$1" == "mesh" ]]; then
	export CLUSTER_COUNT=$2
	licenseFile="/opt/elastic/license.json"

	for ((x=1; x<="$2"; x++)); do
# First cast the loop counter to a string with leading zero if needed:
		echo ""
		declare instance=""
		printf -v instance "%02d" $x;
		declare elasticUrl="$ELASTIC_MESH_HOST/cluster$instance/elastic"

		echo "Adding licence to mesh cluster $x"
		curl -s -k -H "Content-Type: application/json" -X PUT -d @$licenseFile -u "elastic:$ELASTIC_MESH_PASSWORD" "https://cluster$instance-elastic:9200/_license"
	done;

else

	curl -k -X PUT -H "Authorization: ApiKey $ELASTIC_API_KEY" -H "Content-Type: application/json" -d @licenseFile  "${ELASTICSEARCH_URL}/_license"

fi
