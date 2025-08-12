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

  
## AWS CloudFormation Template
The above design can be deployed in AWS with CloudFormation using the AWS [VPC multi-tier](https://github.com/aws-samples/vpc-multi-tier) template, configured with the following parameters:
- pNumAzs = 1 (one Availability Zone)
- pCreateInternetGateway = true
- pCreateSingleNatGateway = true (will create one in the public subnet)
- pTier1Create = true
- pTier2Create = true
- pTier3Create = false

Other parameters should be set as required. Once the template has been deployed as a stack, EC2 instances can be added as follows:
- EC2 instance for NGINX in the public subnet, e.g. at t3.micro instance with Ubuntu 24.04
- EC2 instance for Docker in the private subnet, e.g. 

Note that additional networking/routing will need to be added to get this all working.







