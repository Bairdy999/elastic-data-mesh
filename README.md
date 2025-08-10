# Elastic Data Mesh - Proof-of-Concept Installer
## Introduction
> [!TIP]
> For example implentations of the Data Mesh PoC see:
> - [AWS implementation](https://github.com/Bairdy999/elastic-data-mesh/tree/main/Implementations/AWS)
> - [Ingesting UK Police stop-and-search data into the data mesh](https://github.com/Bairdy999/police-uk-data-ingest)
> - Coming soon - Police UK data app based on NextJS/Elastic MCP and RAG demonstrators

Data Mesh in action with Elasticsearch. Elastic are proposing using [Elasticsearch as the core component of a data mesh framework](https://www.elastic.co/blog/data-mesh-public-sector), enabling an approach that unites the pillars of data mesh into a process to manage distributed data.  
  
To that end, this project aims to allow a Proof-of-Concept data mesh to be quickly created. It uses Docker Compose to easily create an arbitrary number of single-node Elasticsearch clusters running as Docker containers, each configured as a remote cluster for the others, along with a corresponding Kibana instance. The diagram below illustrates this concept (**Note:** the number of containers/clusters is only limited by the resources available to the Docker VM).

<img width="660" height="646" alt="image" src="https://github.com/user-attachments/assets/6642bf8e-3ce3-417f-87bc-27e7cd828645" />

## Proof-of-Concept Description

The PoC consists of the following components:
| Item  | Description |
| ------------- | ------------- |
| [elastic-mesh-create.sh](https://github.com/Bairdy999/elastic-data-mesh/blob/main/elastic-mesh-create.sh) | Used to create a data mesh with an arbitrary number of clusters |
| [elastic-mesh-manage.sh](https://github.com/Bairdy999/elastic-data-mesh/blob/main/elastic-mesh-manage.sh)  | Used to subsequently manage individual clusters via Docker Compose |
| [docker-compose-mesh-certs.yml](https://github.com/Bairdy999/elastic-data-mesh/blob/main/docker-compose-mesh-certs.yml) | The Docker Compose file used by setup to generate CA certs for each cluster in the data mesh |
| [docker-compose-mesh-node.yml](https://github.com/Bairdy999/elastic-data-mesh/blob/main/docker-compose-mesh-node.yml) | The Docker Compose file used to create and configure each cluster in the data mesh |

### Installer Actions
When elastic-mesh-create.sh is run it carries out the following actions (assuming all pre-requisites have been met, [see below](https://github.com/Bairdy999/elastic-data-mesh/blob/main/README.md#prerequisites---docker-vm)):
- Optionally, resets the data mesh by removing any existing clusters (useful to rebuild from scratch or for testing)
- Creates a Linux elastic user to assign file permissions to, and to run the Elastic containers (if it doesn't already exist)
- Creates an external Docker network on the VM (for inter-container networking to avoid creating a large number of routes between each cluster network)
> [!CAUTION]
> Common passwords and encryption key are used for all clusters here for as it's intended as a PoC, for simplicity and to make testing easier. **Disclaimer: DO NOT** use common/shared credentials such as this in Production environments, do so at your own risk!
- Carries out each of the following for use by all clusters (i.e. the same elastic user password for each cluster)
  - Generates a randomised elastic user password
  - Generates a randomised kibana_system password
  - Generates a randomised 32-bit (64 hex characters) Kibana encryption key
  - Writes all generated credentials to a local file
  - Sets up environment variables to be used by Docker Compose for each cluster in the data mesh
- Iterates over the the required number of clusters and carries out the following for each cluster in the data mesh:
  - Creates the relevant folders for certs, elastic and kibana on persistent storage (to be subsequently mounted by Docker)
  - Sets permissions on each folder with the local elastic user as owner
  - Runs a Docker Compose setup container to generate CA certificates for the cluster
  - Copies the CA certs to each of the other clusters for use when configuring remote clusters for cross-cluster-search (CCS)
  - Generates an elasticsearch.yml config file containing relevant networking and security settings
  - Generates a kibana.yml config file containing relevant networking and security settings (this inclydes a banner heading to identify the cluster when logged into Kibana; this avoids confusion and/or error!)
  - Runs Docker Compose to create Elasticsearch and Kibana containers for each cluster, using the already generated configuration and artefacts (e.g. CA certs)
  - Adds the container IP addresses to /etc/hosts for each container
  - Configures each cluster as a remote cluster for every other cluster in the data mesh
  - Generates a cross-cluster API key for each cluster and writes it to a local file in the cluster

## Prerequisites - Docker VM
> [!NOTE]
> Ubuntu 24.04 LTS is used here to run Docker and the Elasticsearch data mesh clusters but feel free to use a Linux flavour of your choice that supports Docker

Create a VM with the following specs:
- OS: Ubuntu 24.04 LTS
- CPU: 2 min, max as required
- Memory: 8GB min, max as required
- Primary volume: 60GB (or as required)
- Second volume: 200GB min, max as required (provisioned/mounted as `/mnt/data` for consistency, can be changed as requird)

## Required software
Install British English dictionary words for password generation:
```
sudo apt-get install wbritish
```
Install Docker:
```
sudo apt install curl apt-transport-https ca-certificates software-properties-common
sudo apt install docker.io -y
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
sudo echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce -y
```

## Running the scripts

### elastic-mesh-create.sh

### elastic-mesh-manage.sh
