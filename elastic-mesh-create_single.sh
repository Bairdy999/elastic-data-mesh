#!/bin/bash
# Usage: ./elastic-mesh-create.sh x (where x is the number of clusters to create via Docker Compose)

if [[ $# -eq 0 ]] ; then
    echo 'Usage: ./elastic-mesh-create.sh x (where x is the number of clusters to create via Docker Compose)'
    exit 0
fi

# Create our elastic system user for mount permissions (it will harmlessly exit if the user already exists):
adduser elastic --system --no-create-home

# Setup our base mount point (see /etc/fstab for mount point details, create/configure as needed for your environment):
elasticBaseDir="/mnt/data/mesh/"
baseDir="/mnt/data/mesh"
mkdir -p $baseDir
# Make the elastic user owner of the mesh folders:
chown -Rf elastic /mnt/data/mesh/

# Create our network if it doesn't already exist (will safely error if it does)
docker network create data-mesh-network

# By using the envsubst method to run docker compose, it doesn't read the local .env file so we need to export any required env vars here (change as needed):
	export ELASTIC_PASSWORD=changeme
	export KIBANA_PASSWORD=changeme
	export ENCRYPTION_KEY=c34d38b3a14956121ff2170e5030b471551370178f43e5626eec58b04a30fae2
	export STACK_VERSION=8.18.1
	export CLUSTER_COUNT=$1

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
#for ((x=1; x<="$1"; x++)); do
#	declare instance=""
#	printf -v instance "%02d" $x;
# Run docker compose for each cluster to create the certs, but without -d so we can wait for the container to finish before continuing:
#	export instance=$instance && envsubst < /opt/data-mesh/docker-compose-mesh-certs.yml | docker compose -p mesh-cluster-certs$instance -f - up
	docker compose -p mesh-cluster-certs -f /opt/data-mesh/docker-compose-mesh-certs.yml up
	docker compose -p mesh-cluster-certs -f /opt/data-mesh/docker-compose-mesh-certs.yml down
#	export instance=$instance && envsubst < /opt/data-mesh/docker-compose-mesh-certs.yml | docker compose -p mesh-cluster-certs$instance -f - down
# And make the elastic user owner of the mesh folders/files:
#	declare clusterBaseDir="$baseDir/cluster$instance"
#	echo "Setting elastic user permissions on $clusterBaseDir"
#	chown -Rf elastic $clusterBaseDir
#done;
exit 0

# Then copy the remote cluster cert to every other cluster to be created:

# Then loop through each cluster to be created as part of the mesh PoC:
for ((x=1; x<="$1"; x++)); do
# First cast the loop counter to a string with leading zero if needed:
	declare instance=""
	printf -v instance "%02d" $x; echo $instance

# Absolute location of elasticsearch.yml file for the cluster (note that without the http.host setting Elasticsearch will fail to bind correctly to its ports):
	declare elasticsearchYmlFile="$clusterElasticDir/elasticsearch.yml"
	printf 'http.host: "0.0.0.0"\n' > $elasticsearchYmlFile
	printf "remote_cluster_server.enabled: true\n" >> $elasticsearchYmlFile

	declare remoteCertAra=" [ "

	for ((y=1; y<="$1"; y++)); do
		printf -v instance "%02d" $y; echo $instance2
		declare remoteCertPath="$baseDir/cluster$instance2/certs/ca/"
	done;

	remoteCertAra=$remoteCertAra" ]"
	printf 'xpack.security.remote_cluster_client.ssl.certificate_authorities: \n' >> $elasticsearchYmlFile 

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
	export instance=$instance && envsubst < /opt/data-mesh/docker-compose-mesh-node.yml | docker compose -p mesh-cluster$instance -f - up -d

#Grab the IP addresses for the containers and add to /etc/hosts:
	declare elasticIP=$(docker exec cluster$instance-elastic hostname -I)
	declare kibanaIP=$(docker exec cluster$instance-kibana hostname -I)
	printf "\n$elasticIP cluster$instance-elastic\n" >> "/etc/hosts"
	printf "$kibanaIP cluster$instance-kibana\n" >> "/etc/hosts"
#echo $elasticIP
done;

