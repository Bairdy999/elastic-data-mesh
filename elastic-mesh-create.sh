#!/bin/bash
# Usage: ./elastic-mesh-create.sh x (where x is the number of clusters to create via Docker Compose)

if [[ $# -eq 0 ]] ; then
    echo 'Usage: ./elastic-mesh-create.sh x (where x is the number of clusters to create via Docker Compose)'
    exit 0
fi

# Get our OS, i.e. Linux or MacOS
osType=$(uname -s)
if [[ "$osType" == "Darwin" ]]; then
	echo "Installation on MacOS is not supported at this time"
	exit 0
fi;

# First create our base directory if it doesn't exist (this assumes the data volume is mounted at /mnt/data if Linux, /opt/dat if Mac):
baseDir="/mnt/data/mesh"

if [[ "$osType" == "Darwin" ]]; then
	baseDir="/opt/data/mesh"
fi;

mkdir -p $baseDir

# Then generate a password for the elastic and kibana_system users (only works on Linux, change on MacOS):
randomPassword="changeme999"
if [[ "$osType" != "Darwin" ]]; then
	randomPassword=$(WORDS=3; LC_ALL=C grep -x '[a-z]*' /usr/share/dict/words | shuf --random-source=/dev/urandom -n ${WORDS} | paste -sd "-")
fi;

# And also the Kibana encryption key
encryptionKey=$(hexdump -vn32 -e'8/4 "%08X" 1 "\n"' /dev/urandom)

# Then write the credentials to a file:
declare passwordFile="$baseDir/credentials.txt"
printf "elastic: $randomPassword\n" > $passwordFile
printf "kibana_system: $randomPassword\n" >> $passwordFile
printf "kibana_encryption_key: $encryptionKey\n" >> $passwordFile


# By using the envsubst method to run docker compose, it doesn't read the local .env file so we need to export any required env vars here (change as needed):
export ELASTIC_PASSWORD=$randomPassword
export KIBANA_PASSWORD=$randomPassword
# Default encryption key as provided by Elastic is well-known so generate a new random key
# export ENCRYPTION_KEY=c34d38b3a14956121ff2170e5030b471551370178f43e5626eec58b04a30fae2
export ENCRYPTION_KEY=$encryptionKey
export STACK_VERSION=8.18.1
export CLUSTER_COUNT=$1
export KB_MEM_LIMIT="2g"
export ELASTIC_MEM_LIMIT="2g"

# Create our elastic system user for mount permissions (it will harmlessly exit if the user already exists):
adduser elastic --system --no-create-home

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

# Now clear out any old entries in /etc/hosts:
cp /etc/hosts /etc/hosts.bak
sed -i '/cluster..-/d' /etc/hosts

# And grab the latest IP addresses for the containers and add to /etc/hosts:
	declare elasticIP=$(docker exec cluster$instance-elastic hostname -I)
	declare kibanaIP=$(docker exec cluster$instance-kibana hostname -I)
	printf "\n$elasticIP cluster$instance-elastic\n" >> "/etc/hosts"
	printf "$kibanaIP cluster$instance-kibana\n" >> "/etc/hosts"
#echo $elasticIP
done;

# And set up the remote clusters in each cluster:
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
