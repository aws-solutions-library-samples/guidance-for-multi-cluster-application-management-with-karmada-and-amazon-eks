# Description

This script automates the deployment of a Karmada cluster on Amazon EKS. It creates an EKS cluster to serve as the Karmada control plane, deploys the Karmada components on it, and joins user-specified number of EKS clusters as member clusters to Karmada.

It performs the following key tasks:

- Checks and installs prerequisites (jq, kubectl, eksctl, aws cli)
- Gets VPC ID and subnets for the EKS clusters
- Creates EKS cluster for Karmada control plane 
- Deploys EBS CSI driver and creates gp3 storage class on control plane cluster
- Deploys network load balancer for Karmada API server
- Installs kubectl Karmada plugin 
- Initializes Karmada on the control plane EKS cluster
- Creates specified number of EKS clusters to serve as member clusters
- Registers each member cluster to the Karmada control plane
- Performs a simple demo deployment across member clusters

# Pre-requisites
The script requires 

- A VPC with three public and three private subnets, for redundancy purposes
- Host with 
AWS cli installed and configured
-

# Arguments

**-e** - EKS cluster version (default: 1.28)

**-v** - VPC name (default: vpc-eks)  

**-r** - AWS region (default: eu-north-1)

**-c** - Cluster name prefix (default: karmada)

**-n** - Number of cluster nodes (default: 3) 

**-p** - Node VCPUs (default: 2)

**-m** - Node memory in GB (default: 4)  

**-a** - Node architecture (default: x86_64)

**-s** - Number of member clusters (default: 2)

**-k** - Karmada HOME directory (default: ~/.karmada)

**-h** - Print help

# Example Usage

```
./karmada-eks-deploy.sh -r us-east-1 -c mykarmada -n 2 -s 3
```

This will create a karmada control plane cluster and 3 member clusters with 2 compute nodes per cluster. The clusters' name prefix is "mykarmada" and all will be deployed in us-east-1 region.

# Cloud9 deployment

Login to your AWS Management console and 
* follow the [official documentation instructions](https://docs.aws.amazon.com/cloud9/latest/user-guide/setting-up.html) to setup your Cloud9 environment.




# Functions

**os_package_manager** - Checks and sets the package manager for the OS

**install_os_packages** - Checks and installs jq

**install_kubectl** - Checks and installs kubectl

**install_eksctl** - Checks and installs eksctl

**install_awscli** - Checks and installs aws cli v2

**get_subnets** - Gets public and private subnets from VPC

**eks_create_cluster** - Creates an EKS cluster 

**eks_set_context** - Sets kubectl context to specified cluster

**eks_deploy_ebs** - Deploys EBS CSI driver on cluster

**eks_karmada_ns** - Checks/creates Karmada namespace

**eks_lb_deploy** - Deploys network load balancer for Karmada

**eks_karmada_plugin_install** - Installs kubectl-karmada plugin

**eks_karmada_deploy** - Deploys Karmada control plane on cluster 

**eks_karmada_register** - Registers a member cluster to Karmada

**eks_karmada_demo_deploy** - Deploys sample app across member clusters 

**eks_karmada_summary** - Prints out summary of deployment