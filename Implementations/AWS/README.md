# Implementing Elastic Data Mesh Proof-of-Concept on AWS
## AWS Design
To provision a fairly representative data mesh PoC, AWS is the ideal platform to allow large Docker VMs to be quickly spun up as EC2 instances. To that end the following logical design has been deployed in AWS for PoC testing purposes:

<img src="https://github.com/user-attachments/assets/f9b333be-6fde-496a-aa2e-df02b1c14f7d" alt="AWS Data Mesh PoC diagram" width="800">

## AWS Components
- Data Mesh VPC
  - Single Availaiblity Zone
- Public Subnet
  - Internet Gateway
  - NAT Gateway
  - NGINX EC2 Instance
- Private Subnet
  - Docker EC2 Instance

  
## AWS CloudFormation Template
The above design can be deployed in AWS with CloudFormation using the AWS [VPC multi-tier](https://github.com/aws-samples/vpc-multi-tier) template, configured with the following parameters:
- pNumAzs = 1 (one Availability Zone)
- pCreateInternetGateway = true
- pCreateSingleNatGateway = true (will create one in the public subnet)
- pTier1Create = true
- pTier2Create = true
- pTier3Create = false

Other parameters should be set as required. Once the template has been deployed as a stack, EC2 instances can be added as follows:
- EC2 instance for NGINX in the public subnet, e.g. a t3.micro instance (2 x CPU, 1GB RAM) with Ubuntu 24.04. See [nginx_example.conf](nginx_example.conf) for an example NGINX config set up for 8 clusters, forwarding to Elasticsearch and Kibana in each cluster
- EC2 instance for Docker in the private subnet, e.g. a t3.2xlarge instance (8 x CPU, 32GB RAM) with Ubuntu 24.04 will allow for a data mesh with 8-10 Elasticsearch clusters

Note that additional networking/routing/security will need to be added to this configuration in line with AWS best practice.







