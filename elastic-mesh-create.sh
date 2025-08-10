#!/bin/bash
# Usage: ./elastic-mesh-create.sh x <reset> (where x is the number of clusters to create via Docker Compose, optionally pass reset to remove all existing clusters)

if [[ $# -eq 0 ]] ; then
    echo './elastic-mesh-create.sh x <reset> (where x is the number of clusters to create via Docker Compose, optionally pass reset to remove all existing clusters)'
    exit 0
fi

# Get our OS, i.e. Linux or MacOS
osType=$(uname -s)
if [[ "$osType" == "Darwin" ]]; then
	echo "Installation on MacOS is not supported at this time"
	exit 0
fi;

# If wer'e passed a reset then remove all existing data:
if [[ "$2" == "reset" ]]; then
	echo "Removing all existing data for reset..."
	rm -Rf /mnt/data/mesh
fi

# First create our base directory if it doesn't exist (this assumes the data volume is mounted at /mnt/data if Linux, /opt/dat if Mac):
baseDir="/mnt/data/mesh"

if [[ "$osType" == "Darwin" ]]; then
	baseDir="/opt/data/mesh"
fi;

mkdir -p $baseDir

elasticPassword=""
kibanaPassword=""
enryptionKey=""
credsFile="$baseDir/credentials.txt"

if [ -f $credsFile ]; then
# Read in the key/value pairs from the cred file it it already exists (we don't want to overwrite the elastic password!)
	echo "File $credsFile exists..."
	elasticPassword=$(grep elastic $credsFile | awk -F= '{print $2}')
	kibanaPassword=$(grep kibana_system $credsFile | awk -F= '{print $2}')
	encryptionKey=$(grep kibana_encryption_key $credsFile | awk -F= '{print $2}')
else
# Then generate a password for the elastic and kibana_system users (only works on Linux, change on MacOS):
	echo "Generating password for elastic and kibana_system users..."
	if [[ "$osType" != "Darwin" ]]; then
		elasticPassword=$(WORDS=3; LC_ALL=C grep -x '[a-z]*' /usr/share/dict/words | shuf --random-source=/dev/urandom -n ${WORDS} | paste -sd "-")
		kibanaPassword=$(WORDS=3; LC_ALL=C grep -x '[a-z]*' /usr/share/dict/words | shuf --random-source=/dev/urandom -n ${WORDS} | paste -sd "-")
	fi;

# And also the Kibana encryption key
	echo "Generating Kibana encryption key..."
	encryptionKey=$(hexdump -vn32 -e'8/4 "%08X" 1 "\n"' /dev/urandom)

# Then write the credentials to a file:
	declare passwordFile="$baseDir/credentials.txt"
	echo "Writing credentials to $passwordFile"
	printf "elastic=$elasticPassword\n" > $passwordFile
	printf "kibana_system=$kibanaPassword\n" >> $passwordFile
	printf "kibana_encryption_key=$encryptionKey\n" >> $passwordFile
fi

# Create our elastic system user for mount permissions (it will harmlessly exit if the user already exists):
adduser elastic --system --no-create-home
# And grab the UID for the elastic user so Docker can run with the correct user UID
elasticUID=$(id -u elastic)
echo "elastic user UID: $elasticUID"

# By using the envsubst method to run docker compose, it doesn't read the local .env file so we need to export any required env vars here (change as needed):
export CLUSTER_COUNT=$1
export ELASTIC_MEM_LIMIT="3g"
export ELASTIC_PASSWORD=$elasticPassword
export ELASTIC_UID=$elasticUID
export ENCRYPTION_KEY=$encryptionKey
export KIBANA_MEM_LIMIT="2g"
export KIBANA_PASSWORD=$kibanaPassword
# Default encryption key as provided by Elastic is well-known so generate a new random key
# export ENCRYPTION_KEY=c34d38b3a14956121ff2170e5030b471551370178f43e5626eec58b04a30fae2
export STACK_VERSION=8.18.1

# Setup our base mount point (see /etc/fstab for mount point details, create/configure as needed for your environment):
elasticBaseDir="/mnt/data/mesh/"
# Make the elastic user owner of the mesh folders:
chown -Rf elastic /mnt/data/mesh/

# Create our network if it doesn't already exist (will safely error if it does)
docker network create data-mesh-network

# First, create all the dirs needed for each cluster:
for ((x=1; x<="$1"; x++)); do
# Cast the loop counter to a string with leading zero if needed:
	declare instance=""
	printf -v instance "%02d" $x;

# Next, declare our base dirs for each cluster:
	declare clusterBaseDir="$baseDir/cluster$instance"
	declare clusterCertsDir="$baseDir/cluster$instance/certs/"
	declare clusterElasticDir="$baseDir/cluster$instance/elastic"
	declare clusterKibanaDir="$baseDir/cluster$instance/kibana"

# And create them if they don't exist:
	mkdir -p $clusterCertsDir
	mkdir -p $clusterElasticDir
	mkdir -p $clusterKibanaDir

# And make the elastic user owner of the mesh folders/files:
	echo "Setting elastic user permissions on $clusterBaseDir"
	chown -Rf elastic $clusterBaseDir
done;

# Next create the CA and remote certs for the given number of clusters (these need to exist in advance of starting each cluster):
for ((x=1; x<="$1"; x++)); do
	declare instance=""
	echo "Generating CA and remote certs for cluster$instance"
	printf -v instance "%02d" $x;
# Run docker compose for each cluster to create the certs, but without -d so we can wait for the container to finish before continuing:
	export instance=$instance && envsubst < /opt/elastic-data-mesh/docker-compose-mesh-certs.yml | docker compose -p mesh-cluster-certs$instance -f - up
	export instance=$instance && envsubst < /opt/elastic-data-mesh/docker-compose-mesh-certs.yml | docker compose -p mesh-cluster-certs$instance -f - down
# And make the elastic user owner of the mesh folders/files:
	declare clusterBaseDir="$baseDir/cluster$instance"
	echo "Setting elastic user permissions on $clusterBaseDir"
	chown -Rf elastic $clusterBaseDir
done;

# Then copy the remote cluster cert to every other cluster to be created:
echo "Copying remote certs to each cluster"
for ((x=1; x<="$1"; x++)); do
	declare instance=""
	printf -v instance "%02d" $x;
	declare clusterCertsDir="$baseDir/cluster$instance/certs/"
	declare clusterRemoteCert="$baseDir/cluster$instance/certs/ca/remote-cluster$instance-ca.crt"

	for ((y=1; y<="$1"; y++)); do
# Skip the copy if it's for the same cluster:
		if [[ "$x" == "$y" ]]; then
			continue
		fi

		printf -v remote_instance "%02d" $y;
		declare targetCertPath="$baseDir/cluster$remote_instance/certs/ca/"
		cp $clusterRemoteCert $targetCertPath
	done;
done;

chown -Rf elastic $baseDir
#exit 0

# Now clear out any old entries in /etc/hosts:
cp /etc/hosts /etc/hosts.bak
sed -i '/cluster..-/d' /etc/hosts

# Then loop through each cluster to be created as part of the mesh PoC:
for ((x=1; x<="$1"; x++)); do
# First cast the loop counter to a string with leading zero if needed:
	echo "Creating mesh cluster $x"
	declare instance=""
	printf -v instance "%02d" $x;

# Next, redeclare our base dirs for each cluster:
	declare clusterBaseDir="$baseDir/cluster$instance"
	declare clusterCertsDir="$baseDir/cluster$instance/certs/"
	declare clusterElasticDir="$baseDir/cluster$instance/elastic"
	declare clusterKibanaDir="$baseDir/cluster$instance/kibana"

# Absolute location of elasticsearch.yml file for the cluster (note that without the http.host setting Elasticsearch will fail to bind correctly to its ports):
	declare elasticsearchYmlFile="$clusterElasticDir/elasticsearch.yml"
	printf 'http.host: "0.0.0.0"\n' > $elasticsearchYmlFile
	printf "remote_cluster_server.enabled: true\n" >> $elasticsearchYmlFile

	declare remoteCertAra=""

# Get a list of all the remote certs for this cluster, separated by a comma:
	declare remoteTempAra=$(find /mnt/data/mesh/cluster$instance/certs/ca/remote* -printf '"certs/ca/%f",')
#	declare remoteTempAra=$(find /mnt/data/mesh/cluster$instance/certs/ca/remote* -printf '"%f",')
# Remove the last comma:
	declare remoteCerts=${remoteTempAra::-1}
# And write to the cluster elasticsearch.yml file:
	declare remoteCertAra="[ $remoteCerts ]"
	printf 'xpack.security.transport.ssl.certificate_authorities: %s\n' "$remoteCertAra" >> $elasticsearchYmlFile 
	printf 'xpack.security.remote_cluster_client.ssl.certificate_authorities: %s\n' "$remoteCertAra" >> $elasticsearchYmlFile 

# Absolute location of kibana.yml file for the cluster:
	declare kibanaYmlFile="$clusterKibanaDir/kibana.yml"

# Create relevant config params in kibana.yml (note that without the server.host setting Kibana will fail to bind correctly to its ports):
	printf 'server.host: "0.0.0.0"\n' > $kibanaYmlFile
	printf 'server.basePath: "/cluster%s"\n' "$instance" >> $kibanaYmlFile
	printf "server.rewriteBasePath: true\n" >> $kibanaYmlFile
	printf "xpack.banners.placement: top\n" >> $kibanaYmlFile
	printf 'xpack.banners.textContent: "Data Mesh - Cluster%s"\n' "$instance" >> $kibanaYmlFile

# And make the elastic user owner of the mesh folders/files:
	chown -Rf elastic $clusterBaseDir

# Finally, run envsubst to substitute the instance Id in the docker compose template file and pipe the result via stdin to docker compose:
	export instance=$instance && envsubst < /opt/elastic-data-mesh/docker-compose-mesh-node.yml | docker compose -p mesh-cluster$instance -f - up -d

# And grab the latest IP addresses for the containers and add to /etc/hosts:
	declare elasticIP=$(docker exec cluster$instance-elastic hostname -I)
	declare kibanaIP=$(docker exec cluster$instance-kibana hostname -I)
	printf "\n$elasticIP cluster$instance-elastic\n" >> "/etc/hosts"
	printf "$kibanaIP cluster$instance-kibana\n" >> "/etc/hosts"
#echo $elasticIP
done;

# And set up the templates for each cluster:
# Template to add remote cluster settings:
remoteTemplate=$(cat <<EOF
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

# Template to create API key:
apiKeyTemplate=$(cat <<EOF
{
  "name": "clusterxx-ccs-api-key",
  "expiration": "365d",
  "access": {
    "search": [
      {
        "names": ["mesh*"]
      }
    ]
  },
  "metadata": {
    "description": "elastic-data-mesh-poc",
    "environment": {
      "level": 1,
      "trusted": true,
      "tags": ["dev", "poc"]
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

# Then loop through and add the remote clusters to the current one:
	for ((y=1; y<="$1"; y++)); do
# Skip the remote cluster if it's for the same cluster:
		if [[ "$x" == "$y" ]]; then
			continue
		fi

		printf -v remoteInstance "%02d" $y;
		declare remoteSettings="${remoteTemplate//"xx"/$remoteInstance}"
		curl -k -H "Content-Type: application/json" -X PUT -d "$remoteSettings" -u "elastic:$ELASTIC_PASSWORD" "https://cluster$instance-elastic:9200/_cluster/settings"
	done;
done;

echo "Creating API keys"
apiKeyFile=""
for ((x=1; x<="$1"; x++)); do
# First cast the loop counter to a string with leading zero if needed:
	declare instance=""
	printf -v instance "%02d" $x;

	apiKeyFile="$baseDir/cluster$instance/cluster$instance-ccs-api-key.json"

	declare apiKeyRequest="${apiKeyTemplate//"xx"/$instance}"
	declare json=""
	json=$(curl -s -k -H "Content-Type: application/json" -X POST -d "$apiKeyRequest" -u "elastic:$ELASTIC_PASSWORD" "https://cluster$instance-elastic:9200/_security/cross_cluster/api_key")

#	printf "$json" > $apiKeyFile
# Pretty print our API key json to file:
	echo $json | jq > $apiKeyFile
done;