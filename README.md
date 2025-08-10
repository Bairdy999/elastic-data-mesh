# Elastic Data Mesh - Proof-of-Concept Installer
## Introduction

Data Mesh in action with Elasticsearch. Elastic are proposing using [Elasticsearch as the core component of a data mesh framework](https://www.elastic.co/blog/data-mesh-public-sector), enabling an approach that unites the pillars of data mesh into a process to manage distributed data.  
  
To that end, this project aims to allow a Proof-of-Concept data mesh to be quickly created. It uses Docker Compose to easily create an arbitrary number of single-node Elasticsearch clusters running as Docker containers, each configured as a remote cluster for the others, along with a corresponding Kibana instance. The diagram below illustrates this concept (**Note:** the number of containers/clusters is only limited by the resources available to the Docker VM).

<img width="660" height="646" alt="image" src="https://github.com/user-attachments/assets/6642bf8e-3ce3-417f-87bc-27e7cd828645" />

The 'installer' consists of the following components:
| Item  | Description |
| ------------- | ------------- |
| [elastic-mesh-create.sh](https://github.com/Bairdy999/elastic-data-mesh/blob/main/elastic-mesh-create.sh) |   |
| [elastic-mesh-manage.sh](https://github.com/Bairdy999/elastic-data-mesh/blob/main/elastic-mesh-manage.sh)  |   |
| [docker-compose-mesh-certs.yml](https://github.com/Bairdy999/elastic-data-mesh/blob/main/docker-compose-mesh-certs.yml) |  |
| [docker-compose-mesh-node.yml](https://github.com/Bairdy999/elastic-data-mesh/blob/main/docker-compose-mesh-node.yml) |  |

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
