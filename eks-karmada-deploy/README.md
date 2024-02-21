# Automatic Amazon EKS and Karmada deployment

## Description

This script automates the deployment of a Karmada cluster on Amazon EKS. It creates an EKS cluster to serve as the Karmada control plane, deploys the Karmada components on it, and joins user-specified number of EKS clusters as member clusters to Karmada.

The main tasks of the script are the following:

- Check and install, if missing, some prerequisites (jq, kubectl, eksctl, aws cli)
- Deploy an EKS cluster for Karmada control plane (parent)
  - Deploy EBS CSI driver and create a gp3 storage class on control plane cluster (parent)
  - Deploy network load balancer for Karmada API server
- Deploy specified number (default 2) of EKS clusters to serve as member clusters
  - Register each member cluster to the Karmada control plane
- Installs kubectl Karmada plugin
- Initialize Karmada on the control plane EKS cluster (parent)
- Perform a simple demo deployment of a kubernetes workload across two member clusters with 50%-50% distribution

## Prerequisites

To run the script you need the following in place:  

- An active [AWS Account](https://docs.aws.amazon.com/accounts/latest/reference/welcome-first-time-user.html) to deploy the main Amazon EKS cluster.
- Αn [Amazon VPC](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/gsg_create_vpc.html) with:
  - three public [subnets](https://docs.aws.amazon.com/vpc/latest/userguide/create-subnets.html) and enabled the option to auto-assign [public IPv4 address during instance launch](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-instance-addressing.html#public-ip-addresses)
  - three private subnets
- An [Internet Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html) with a default route from public subnets
- A [NAT gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) with default route from private subnets to allow Internet access for all cluster nodes.
- A [user with adequate permissions to create, delete Amazon EKS clusters access](https://docs.aws.amazon.com/streams/latest/dev/setting-up.html) and an [Access key/Secret access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html) to configure [AWS Command Line Interface](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (AWS CLI).

## Arguments

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
**-u** - Run the script unattended
**-z** - Skip check and install of required utilities jq, aws cli v2, eksctl, kubectl
**-d** - Delete the deployed EKS clusters and karmada resources
**-h** - Print help

## Example Usage

The following run deploys infrastructure in the US East (N. Virginia) region using for EKS clusters the prefix "mykarmada" with 3 member clusters. 

```bash
./deploy-karmada-run.sh -r us-east-1 -c mykarmada -s 3
```

This will create a karmada control plane cluster and 3 member clusters with 2 compute nodes per cluster. The clusters' name prefix is "mykarmada" and all will be deployed in us-east-1 region.

## Deployment 

### Management host deployment

This script creates configuration files and state file (ex. Karmada API server certificates), so it is strongly recommended to run it from a stateful host with appropriate backup and access. We recommend deploying an EC2 instance in your VPC and assign an Instance Profile with Administrator Access so as to be able to deploy EKS clusters and other services. After the EC2 instance is ready, proceed with the "Deployment commands" below.

### Deploy with AWS CloudShell

This script can be run directly from the [AWS Management Console](https://aws.amazon.com/console/) using the [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html) for you convinience.

**WARNING** CloudShell is designed for focused, task-based activities. It is **not** meant for tasks that need to keep state and persistent data (ex. installation of system packages). Also, your shell session automatically ends after approximately 20–30 minutes if you don't interact with AWS CloudShell using your keyboard or pointer. Running processes don't count as interactions, so while running this script make sure that you interact with the shell (ex. press Enter key) every 15 minutes to avoid timeouts and interrupting the script run. and its use in this solutions is only recommended as a means for quick testing and you should **never** rely on it for production use.

The use of AWS CloudShell for this solutions is only recommended as a means for quick testing. If you want to perform a production grade deployment using an AWS service with more flexible timeouts and data persistency, we recommend using our cloud-based IDE, [AWS Cloud9](https://docs.aws.amazon.com/cloud9), or launching and [connecting to an Amazon EC2 instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstances.html).

Assuming you are logged in to the AWS Management Console using a user with adequate permissions, open a CloudShell follow the "Deployment commands" below.

### Deploy with AWS Cloud9

Another option to have a stable and stateful deployment with minimum administration overhead and reduced cost, is to use [AWS Cloud9](https://aws.amazon.com/cloud9/). Follow the official documentation for [Creating an EC2 Environment](https://docs.aws.amazon.com/cloud9/latest/user-guide/create-environment-main.html) to create a new Cloud9 environment in the same VPC as the one you are going to use for Karmada deployment. Due to the nature of the deployment you cannot use AWS Cloud9 temporary credentials, but instead you have two options. Either [Create and use an instance profile to manage temporary credentials](https://docs.aws.amazon.com/cloud9/latest/user-guide/credentials.html#credentials-temporary) or [Create and store permanent access credentials in an Environment](https://docs.aws.amazon.com/cloud9/latest/user-guide/credentials.html#credentials-permanent-create).

As long as you setup the credentials start a new terminal session (on the menu bar, choose Window, New Terminal) and follow the "Deployment commands" below.

### Deployment commands

1. Clone from Github this [solution repository](https://github.com/aws-solutions-library-samples/guidance-for-multi-cluster-management-eks-karmada)

```bash
git clone https://github.com/aws-solutions-library-samples/guidance-for-multi-cluster-management-eks-karmada.git
```

2. Go into the script directoy

```bash
cd guidance-for-multi-cluster-management-eks-karmada/eks-karmada-deploy/
```

3. Do the script executable

```bash
chmod +x deploy-karmada-run.sh
```

4. Run the script with the required parameters (or -h for help)

```bash
./deploy-karmada-run.sh -r eu-north-1 -c Karmada -v KarmadaVPC
```

5. Wait for the script to run. As long as you do not have any EKS clusters already deployed, expect roughly 30-60 minutes (depending on number of clusters) in total for the script to complete.

## Idempotency

The script is not idempotent but all reasonable effort has been put into this direction and can be safely run again with the same parameters. If it has failed before, fix the error and run it again, it should be able to recover from most of the errors that can make it fail. In any case, there are numerous checks within the script to avoid create duplicate resources. Below you can see a sample output of the script the has been run again, with the same parameters, after a successful deployment.

```bash
[cloudshell-user@ip-10-6-24-83 ~]$ ./deploy-karmada-run.sh -v karmada -r eu-west-3 -c par-karmada
Ready to run the Karmada deployment script with the following parameters:
  Amazon EKS version: latest
  VPC name: karmada
  Region: eu-west-3
  Cluster name prefix: karmada
  Cluster nodes: 3
  Cluster nodes CPUs: 2
  Cluster nodes memory: 4
  Cluster CPU arch: x86_64
  Number of karmada member clusters: 2
  Karmada HOME dir: /home/cloudshell-user/.karmada

Please note that depending on the number of clusters you are deploying,
this script may take a while to complete (expect 20+ minutes per cluster).

Press enter to continue or Ctrl-C to abort     
▷ Checking prerequisites
        ✔ jq already installed
        ✔ kubectl already installed
        ✔ eksctl already installed
        ✔ aws cli v2 already installed
▷ Prepare some parameters
        ✔ VPC ID: vpc-XXX
        ✔ Private Subnets: subnet-XXX1,subnet-XXX2,subnet-XXX3
        ✔ Public Subnets: subnet-YYY1,subnet-YYY2,subnet-YYY3
        ✔ Account ID: XYZ
▷ Creating the Karmada parent cluster
        ◔ check if cluster karmada-parent exists ✔
▷ Deploy the EBS addon for Karmada HA
        ◔ switching to the right context ✔
        ◔ associate the IAM OIDC provider ✔
        ◔ create IAM service account ✔
        ◔ deploy EBS addon ✔
        ◔ create gp3 ebs storage class ✔
▷ Creating the Karmada member clusters
        ◔ check if cluster karmada-member-1 exists ✔
        ◔ check if cluster karmada-member-2 exists ✔
▷ Deploy Karmada Load Balancer
        ◔ switching to the right context ✔
        ◔ switching to the right context ✔
        ◔ check if namespace karmada-system exists ✔
        ◔ check if karmada network load balancer exists ✔
        ✔ Karmada Load Balancer DNS name: af4bcd409267c4b9186e09b69043f23f-8f6aba280018d831.elb.eu-west-3.amazonaws.com
▷ Deploy Karmada Control Plane
        ◔ switching to the right context ✔
        ✔ kubectl-karmada already installed
        ◔ check if karmada is already initialised ✔
▷ Registering the Karmada member cluster karmada-member-1 to Karmada
        ✔ kubectl-karmada already installed
        ◔ switching to the right context ✔
        ◔ check if par-karmada-member-1 is already registered to Karmada cluster ✔
▷ Registering the Karmada member cluster karmada-member-2 to Karmada
        ✔ kubectl-karmada already installed
        ◔ switching to the right context ✔
        ◔ check if par-karmada-member-2 is already registered to Karmada cluster ✔
▷ Deploying demo application (nginx) to member clusters karmada-member-1 and karmada-member-2
        ◔ switching to the right context ✔
        ◔ check if propagation policy exists ✔
        ◔ check if deployment exists ✔
        ◔ check deployment in cluster karmada-member-1
        ◔ switching to the right context ✔
NAME                                 READY   STATUS    RESTARTS   AGE
karmada-demo-nginx-f68bf9f77-gj9wp   1/1     Running   0          108m
karmada-demo-nginx-f68bf9f77-v467n   1/1     Running   0          108m
        ◔ check deployment in cluster karmada-member-2
        ◔ switching to the right context ✔
NAME                                 READY   STATUS    RESTARTS   AGE
karmada-demo-nginx-f68bf9f77-28ggx   1/1     Running   0          108m
karmada-demo-nginx-f68bf9f77-zt6bl   1/1     Running   0          108m
▷ Switching to the Karmada parent cluster context
        ◔ switching to the right context ✔

▷▷▷ Karmada deployment is complete!
        ▷ Karmada settings directory: /home/cloudshell-user/.karmada

        ▷ To get info for your cluster status run:
          kubectl --kubeconfig /home/cloudshell-user/.karmada/karmada-apiserver.config get clusters

          You can get more info for advanced Karmada capabilities such as multi-cluster scaling, multi-cluster failover or autoscaling across different clusters
          by visiting the official Karmada documentation at https://karmada.io/docs/userguide/ 
```

## Uninstall

The script has the *-d* parameter to perform a basic clean up of the environment. The script deletes the deployed EKS clusters with the prefix name you define and deletes the configuration directory of karmada. Be *VERY CAREFULL** using this automatic cleanup function and make sure you pass the correct parameters so as not to delete the wrong EKS clusters in your environment. Since there is no safe way to do a complete cleanup, please check and delete manually if necessary the following resources, deployed by the script:

- Network load balancer
- IAM roles
- EBS volumes
