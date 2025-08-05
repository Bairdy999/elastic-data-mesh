# Elastic Data Mesh

## Prerequisites

Create VM with the following specs:
	OS: Ubuntu 24.04 LTS
	CPU: 2 min, max as required
	Memory: 4GB min, max as required
	Primary volume: 60GB
	Second volume: 200GB min, max as required
=======
# Elastic Data Mesh - Proof-of-Concept Installer



## Prerequisites - VM
> [!NOTE]
> Ubuntu 24.04 LTS is used to run Docker and the Elasticsearch data mesh clusters but feel free to use a Linux flavour of your choice that supports Docker

Create a VM with the following specs:
- OS: Ubuntu 24.04 LTS
- CPU: 2 min, max as required
- Memory: 8GB min, max as required
- Primary volume: 60GB (or as required)
- Second volume: 200GB min, max as required

## Prerequisites - required software
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
