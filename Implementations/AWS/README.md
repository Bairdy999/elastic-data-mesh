# Implementing Elastic Data Mesh Proof-of-Concept on AWS
## AWS Design
To provision a fairly representative data mesh PoC, AWS is the ideal platform to allow large Docker VMs to be quickly spun up as EC2 instances. To that end the following logical design has been created in AWS for PoC testing purposes:

<img src="https://github.com/user-attachments/assets/f9b333be-6fde-496a-aa2e-df02b1c14f7d" alt="AWS Data Mesh PoC diagram" width="800">

## Cloud Components
- Data Mesh VPC
  - Single Availaiblity Zone
- Public Subnet
  - Internet Gateway
  - NAT Gateway
  - NGINX EC2 Instance
- Private Subnet
  - Docker EC2 Instance

  
## CloudFormation Template
The above design can be deployed in AWS with CloufFormation using the provided [mesh-data-vpc.json](mesh-data-vpc.json) template






