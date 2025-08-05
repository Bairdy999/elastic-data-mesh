#!/bin/bash

export ELASTIC_PASSWORD=changeme

# Get a list of all the remote certs for this cluster:

# PUT _cluster/settings
remote_template=$(cat <<EOF
{
  "persistent": {
    "cluster": {
      "remote": {
        "clusterxx-elastic": {
          "skip_unavailable": true,
          "mode": "sniff",
          "proxy_address": null,
          "proxy_socket_connections": null,
          "server_name": null,
          "seeds": [
            "clusterxx-elastic:9300"
          ],
          "node_connections": 3
        }
      }
    }
  }
}
EOF
)

echo "Adding remote clusters"
for ((x=1; x<="$1"; x++)); do
# First cast the loop counter to a string with leading zero if needed:
	declare instance=""
	printf -v instance "%02d" $x;

	for ((y=1; y<="$1"; y++)); do
# Skip the remote cluster if it's for the same cluster:
		if [[ "$x" == "$y" ]]; then
			continue
		fi

		printf -v remote_instance "%02d" $y;
		declare remote_settings="${remote_template//"xx"/$remote_instance}"
		curl -k -H "Content-Type: application/json" -X PUT -d "$remote_settings" -u "elastic:$ELASTIC_PASSWORD" "https://cluster$instance-elastic:9200/_cluster/settings"
	done;
done;

exit 0

instance="02"

echo $remote_template
remote_settings="${remote_template//"xx"/$instance}"
echo $remote_settings

curl -k -H "Content-Type: application/json" -X PUT -d "$remote_settings" -u "elastic:$ELASTIC_PASSWORD" "https://cluster01-elastic:9200/_cluster/settings"

#for file in /mnt/data/mesh/cluster01/certs/ca/remote*; do
#  printf "%f "
#done