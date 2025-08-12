# Elastic Data Mesh Proof-of-Concept (PoC)
## Introduction - Data Mesh in action with Elasticsearch
Elastic have proposed using [Elasticsearch as the core component of a data mesh framework](https://www.elastic.co/blog/data-mesh-public-sector), enabling an approach that unites the four pillars of a data mesh into a process to manage, and comprehensively search, distributed data.  

> [!TIP]
> For example implementations/usage of the Data Mesh PoC see:
> - [AWS implementation](Implementations/AWS)
> - [Ingesting UK Police stop-and-search data into the data mesh](https://github.com/Bairdy999/elastic-police-uk-data-ingest)
> - Coming soon - Police UK data mesh app based on NextJS/Elastic MCP and RAG demonstrators
  
> [!NOTE]
> This project is primarily aimed at self-managed and/or air-gapped environments. Integration with Elastic Cloud Hosting or Serverless may be added in future iterations, but the concepts can be equally applied
  
To that end, this project aims to allow a technical Proof-of-Concept data mesh to be quickly created, that could form the basis for a full data mesh framework. It uses Docker Compose to easily create an arbitrary number of single-node Elasticsearch clusters running as Docker containers, each configured as a remote cluster for the others, along with a corresponding Kibana instance. The diagram below illustrates this concept (**Note:** the number of containers/clusters is only limited by the resources available to a single Docker VM. It is left as an exercise to the reader to expand this project to run across multiple Docker VMs).

<img width="660" height="646" alt="image" src="https://github.com/user-attachments/assets/6642bf8e-3ce3-417f-87bc-27e7cd828645" />

## Proof-of-Concept Installer

The 'installer' consists of the following items:
| Item  | Description |
| ------------- | ------------- |
| [elastic-mesh-create.sh](elastic-mesh-create.sh) | Used to create a data mesh with an arbitrary number of clusters |
| [elastic-mesh-manage.sh](elastic-mesh-manage.sh)  | Used to subsequently manage individual clusters via Docker Compose |
| [docker-compose-mesh-certs.yml](docker-compose-mesh-certs.yml) | The Docker Compose file used by setup to generate CA certs for each cluster in the data mesh |
| [docker-compose-mesh-node.yml](docker-compose-mesh-node.yml) | The Docker Compose file used to create and configure each cluster in the data mesh |

### Installer Actions
When `elastic-mesh-create.sh` is run it carries out the following actions (assuming all pre-requisites have been met, [see below](https://github.com/Bairdy999/elastic-data-mesh/blob/main/README.md#prerequisites---docker-vm)):
- Optionally, resets the data mesh by removing any existing clusters (useful to rebuild from scratch or for testing)
- Creates a Linux elastic user to assign file permissions to, and to run the Elastic containers (if it doesn't already exist)
- Creates an external Docker network (`data-mesh-network`) on the VM (for inter-container networking to avoid creating a large number of routes between each cluster network)
> [!CAUTION]
> Common passwords and encryption key are used for all clusters here as it's intended as a PoC, for simplicity and to make testing easier. **Disclaimer: DO NOT** use common/shared credentials such as this in Production environments, do so at your own risk!
- Carries out each of the following for use by all clusters (i.e. the same elastic user password for each cluster)
  - Generates a randomised elastic user passphrase
  - Generates a randomised kibana_system passphrase
  - Generates a randomised 32-bit (64 hex characters) Kibana encryption key
  - Writes all generated credentials to a local file
  - Sets up environment variables to be used by Docker Compose for each cluster in the data mesh
- Iterates over the the required number of clusters and carries out the following for each cluster in the data mesh:
  - Creates the relevant folders for certificates, elastic and kibana on persistent storage (to be subsequently mounted into each container by Docker)
  - Sets permissions on each folder with the local elastic user as owner
  - Runs a Docker Compose setup container to generate CA certificates for the cluster
  - Copies the CA certs to each of the other clusters for use when configuring remote clusters for cross-cluster-search (CCS)
  - Generates an `elasticsearch.yml` config file containing relevant networking and security settings
  - Generates a `kibana.yml` config file containing relevant networking and security settings (this includes a banner heading to identify the cluster when logged into Kibana; this avoids confusion and/or error!)
  - Runs Docker Compose to create Elasticsearch and Kibana containers for each cluster, using the already generated configuration and artefacts (e.g. CA certs)
  - Maps external ports to the relevant internal ports based on the cluster number
  - Adds the container IP addresses to `/etc/hosts` for each container
  - Configures each cluster as a remote cluster for every other cluster in the data mesh
  - Generates a cross-cluster API key for each cluster and writes it to a local file in the cluster
  - Configures Kibana `server.basePath: "/clusterxx"` for external access to Kibana

### Network Details
As mentioned above, the installer adds relevant container IP addresses to the local `/etc/hosts` file for each cluster created. Along with the port mappings, these have a consistent format as follows:
  
| Cluster | Container | Hosts entry name | Port mappings | 
| -- | -- | -- | -- |
| cluster01 | Elasticsearch | cluster01-elastic | 9201->9200<br>9301->9300<br>9401->9443 |
| cluster01 | Kibana | cluster01-kibana | 5601->5601 |
| cluster02 | Elasticsearch | cluster02-elastic | 9202->9200<br>9302->9300<br>9402->9443 |
| cluster02 | Kibana | cluster02-kibana | 5602->5601 |
| clusterxx | Elasticsearch | clusterxx-elastic | 92xx->9200<br>93xx->9300<br>94xx->9443 |
| clusterxx | Kibana | clusterxx-kibana | 56xx->5601 |
  
These hosts entries and port mappings can subsequently be used to access relevant services in each container, or to route traffic to the containers via a reverse proxy. Note that within the Docker VM the standard ports can be accessed directly using the hosts entries, e.g. `https://cluster01-elastic:9200`, `https://cluster02-elastic:9200`, etc.
  
## Prerequisites - Docker VM
> [!NOTE]
> Ubuntu 24.04 LTS is used here to run Docker and the Elasticsearch data mesh clusters but feel free to use a Linux flavour of your choice that supports Docker

Create a VM with the following specs:
- OS: Ubuntu 24.04 LTS
- CPU: 2 min, max as required
- Memory: 8GB min, max as required
- Primary volume: 60GB (or as required)
- Second volume: 200GB min, max as required (provisioned/mounted as `/mnt/data` for consistency, can be changed as required)

## Required software
Install a suitable dictionary words package for passphrase generation, e.g. to install British English:
```
sudo apt-get install wbritish # Installs to /usr/share/dict
```
> [!NOTE]  
> Other variants or languages are available for installation in `/usr/share/dict`, e.g. [US English](https://pkgs.org/download/wamerican), [French](https://pkgs.org/download/wfrench), [Spanish](https://pkgs.org/download/wspanish) etc

Install Docker:
```
sudo apt install curl apt-transport-https ca-certificates software-properties-common
sudo apt install docker.io -y
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
sudo echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce -y
```
## Optional Software
For representative testing, and for external access to Elasticsearch and Kibana it is very useful to install a reverse proxy. For this project NGINX is the reverse proxy of choice but others can be used. NGINX can be installed in one of two ways:
- On the same VM as Docker and the data mesh itself
- On a separate VM with appropriate network connections to the Docker VM  
  
There are advantages and disadvantages of each approach but a separate VM is a more robust and scaleable pattern. It is left to the reader to implement as per their preference but see [AWS implementation](Implementations/AWS) for an example of deploying into AWS with NGINX in a public subnet and Docker in a private subnet

## Running the scripts
### Installation
Clone this github repo to a suitable Docker VM in your environment, e.g. assuming `/opt/elastic-data-mesh` is to be used:
```
cd /opt
git clone https://github.com/Bairdy999/elastic-data-mesh.git
cd /opt/elastic-data-mesh
./elastic-mesh-create 8
```

### Creating a data mesh cluster
#### Items of note (and current limitations/constraints/gotchas)
- As Docker Compose doesn't support dynamic runtime variables, e.g. in a `for` loop for the cluster instance number (standard environment variables themselves aren't dynamic variables in the same context), the [Docker Compose YAML create file](docker-compose-mesh-node.yml) is treated as a template, passed to the [envsubst](https://manpages.ubuntu.com/manpages/noble/man1/envsubst.1.html) process to inject the cluster instance number, and then the resultant YAML piped to Docker Compose via stdin. As such it cannot currently be used directly with Docker Compose.
- When `envsubst` is used, Docker compose can't/doesn't read from a local .env file if it exists (normally it does if ran directly). Any environment variables intended to be used by containers therefore need to be exported priot to running Docker Compose in this manner
- Things such as the Elasticsearch stack version and Docker container memory limits aren't parameterised (yet) but exported as environment variables to Docker Compose prior to running `envsubst`. Change these directly in the script for now if need be
- Running in a VM on Proxmox, exporting environment variable `ELASTIC_MEM_LIMIT="2g"` to the container as `mem_limit: ${ELASTIC_MEM_LIMIT}` worked successfully with 8 clusters. On an AWS EC2 instance with 8 clusters this needed to be increased to `ELASTIC_MEM_LIMIT="3g"`otherwise containers would exit with out-of-memory errors. It is assumed this is a timing issue related to AWS EC2 (YMMV - your mileage may vary!)
- For some reason (and it appears to be a known issue), if environment variables AND an `elasticsearch.yml` file are presented to Elasticsearch in a container, any host binding (e.g. for network, http, transport, etc) must be added for "0.0.0.0" otherwise network connections don't work as expected (this can easily be reproduced by removing the relevant config items for "0.0.0.0" binding)
- A cross-cluster-search API key is created for each cluster but not yet used (it needs to be copied to each other cluster in the data mesh and this can be done manually)

#### Running the script
| Script | Argument 1 | Argument 2 |
| ------------- | ------------- | ------------- |
| [elastic-mesh-create.sh](elastic-mesh-create.sh) | Number of clusters, mandatory, integer | "reset", string, optional |
  
Example usage to create a data mesh with 8 clusters and remove any existing clusters:  
`sudo /opt/elastic-mesh-create.sh 8 reset`

The following screenshot shows the folders that are created for the data mesh:  
  
  <img width="253" height="304" alt="image" src="https://github.com/user-attachments/assets/5ef3de44-c256-4f69-adb6-a1ec92b6570b" />  


  
## 
Once the script has completed and all containers are running, logging into Kibana for cluster01 and navigating to Stack Management->Remote Clusters should look something like this:  

  
<img width="800" alt="image" src="https://github.com/user-attachments/assets/20f2eba0-7a4e-4175-8706-ef78a2f25cde" />  

  
### Managing the data mesh cluster
#### Items of note 
- TBC

#### Running the script
| Script | Argument 1 | Argument 2 | Argument 3 |
| ------------- | ------------- | ------------- | ------------- |
| [elastic-mesh-manage.sh](elastic-mesh-manage.sh) | Docker compose command, mandatory, string, e.g. up/down/restart | Start cluster, mandatory, integer | Number of clusters to apply command to, optional, integer, defaults to 1 |
  
Example usage to restart 8 clusters in the data mesh starting from cluster 1:  
`sudo /opt/elastic-mesh-manage.sh restart 1 8`

## Next Steps
Once the data mesh is up and running, the next steps are suggested as follows:
- Load some data into each cluster. The important requirement here is that the data is different in each cluster so that cross-cluster-search across the data mesh can be tested. See [Ingesting UK Police stop-and-search data into the data mesh](https://github.com/Bairdy999/elastic-police-uk-data-ingest) for an example of such data (or use any suitable data set)
- Create local data views in each cluster for the data that's been loaded, e.g. named `local-data-set`
- In at least one cluster in the data mesh, create a data view that includes the local data views from the other clusters, e.g
  - Assuming each cluster is named `cluster01`, `cluster02`, `cluster03`, etc and has a local data view named `local-data-set`, then
  - Create a mesh data view named `mesh-data-set` that has an index pattern of `cluster*:local-data-set` See [using data views with cross cluster search](https://www.elastic.co/docs/explore-analyze/find-and-organize/data-views#management-cross-cluster-search) for more information on this
  - Use data view `mesh-data-set` anywhere a data view is normally used to explore searching across all clusters in the data mesh against the ingested data
- Configure the generated API key for use so that role-based access to data in the cluster is enforced. The API keys have a default index pattern of `mesh*` configured to restrict search to that pattern
- Setup external access to each cluster in the data mesh to allow access to Kibana and to ingest data into each cluster. There are several mechanisms for doing this, one example using NGINX can be found at [AWS implementation](Implementations/AWS)


