---
title: Multi-cluster application management with EKS and Karmada on AWS 
description: "This implementation guide provides an overview of the 'Multi-cluster application management with EKS and Karmada on AWS' guidance,
its reference architecture and components, considerations for planning the deployment, and configuration steps for deploying the Guidance
name to Amazon Web Services (AWS).
This guide is intended for solution architects, business decision makers, DevOps engineers, data scientists, and cloud professionals who
want to implement { Guidance name } in their environment."
published: true
sidebar: mcm_ekskarmada_sidebar
permalink: compute/multi-cluster-management-with-amazon-eks-karmada.html
tags:    
layout: page
---

---

## Overview

This implementation guide describes architectural considerations and configuration steps for deploying a federated Kubernetes environment in [Amazon Web Services (AWS)](aws.amazon.com) Cloud using [Amazon Elastic Kubernetes Service (Amazon EKS)](https://aws.amazon.com/eks) and the open source Kubernetes Armada [(Karmada)](https://www.cncf.io/blog/2022/03/22/karmada-multi-cluster-management-with-an-ocean-of-nodes/) project. Karmada is a [Kubernetes](https://kubernetes.io/) management system with advanced scheduling capabilities, that enables you to run your cloud-native applications across multiple Kubernetes clusters and clouds, with no changes to your applications. This guide focuses on deploying Karmada on top of a highly available Amazon EKS cluster.

The intended audience of this guide are infrastructure engineers, architects, system administrators, devops professionals and platform engineers who have practical experience architecting in the AWS Cloud and are familiar with Kubernetes technology.


???The 'Multi-cluster application management with EKS and Karmada on AWS' helps you with the deployment and use of the open source project [Karmada](https://karmada.io/) for [Kubernetes](https://kubernetes.io/) multi-cluster management. Karmada is a Kubernetes management system with advanced scheduling capabilities, that enables you to run your cloud-native applications across multiple Kubernetes clusters and clouds, with no changes to your applications. With this Guidance you will be able to setup a federated Kubernetes environment in Amazon Web Services (AWS) Cloud using [Amazon Elastic Kubernetes Service (Amazon EKS)](https://aws.amazon.com/eks/). The purpose of this guidance is to provide both step-by-step instructions and also an opinionated automation script, to deploy an [Amazon EKS](https://aws.amazon.com/eks/) cluster that will host Karmada control plane to act as the parent cluster for multi-cluster management. You also have the option to use existing Amazon EKS clusters or [create new](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html) Amazon EKS clusters that will act as member clusters. With this Guidance you will also have a sample workload distributed among the member clusters to demonstrate a portion of the capabilities of Karmada.???

### Features and benefits

The 'Multi-cluster application management with EKS and Karmada on AWS' guidance provides the following features:

1. Provide step-by-step instructions to deploy an Amazon EKS cluster that will host Karmada control plane and act as a parent cluster for multi-cluster management. We assume that you already have other  EKS clusters deployed which will act as member clusters. 
2. This guide helps you deploy a proof of concept containerized workload distributed among the member clusters.
3. By implementing this guidance, you will be able to manage your Kubernetes cluster workloads from a unified management point for all cluster, in other words, a "single pane of glass".


 ???It allows you to have central management since it is cluster location agnostic and support clusters in public cloud, on-prem or edge. It is compatible with the Kubernetes Native API and enables seamless integration of existing Kubernetes tool chain. It also provides out of the box, built-in policy sets for multiple scenarios such as active-active, remote disaster recovery and geo redundancy. You can also use advanced scheduling policies to achieve cluster affinity, multi-cluster split or rebalance and multi-dimension high availability on the level of Region, Availability Zone, Cluster or Provider.

Kubernetes Native API Compatible

Zero change upgrade: from single-cluster to multi-cluster; Seamless integration of existing K8s tool chain
Open and Neutral

Jointly initiated by Internet, finance, manufacturing, teleco, cloud providers, etc. Target for open governance with CNCF
Avoid Vendor Lock-in

Integration with mainstream cloud providers; Automatic allocation, migration across clusters; Not tied to proprietary vendor orchestration
Out of the Box

Built-in policy sets for scenarios: Active-active, Remote DR, Geo Redundant
Fruitful Scheduling Policies

Cluster Affinity; Multi Cluster Splitting/Rebalancing; Multi-Dimension HA: Region/AZ/Cluster/Provider
Centralized Management

Cluster location agnostic; Support clusters in public cloud, on-prem or edge ????

\<Feature 1 definition and benefit \>

### Use cases

With Karmada, organizations can streamline workload distribution, optimize resource utilization, and enhance resilience across diverse Kubernetes environments. Use cases for multi-cluster management with Karmada include:

- Hybrid Deployments
Karmada is instrumental in facilitating hybrid deployments, enabling organizations to seamlessly distribute applications across diverse environments, including on-premises data centers, AWS and other cloud providers. This capability empowers businesses to harness the advantages of both environments while ensuring consistent management and orchestration through Kubernetes. With Karmada, organizations can optimize resource utilization, enhance resilience, and maintain operational efficiency across their hybrid cloud infrastructure.

- Geographically Distributed Workloads
For customers with a global presence, Karmada facilitates the deployment of applications across geographically distributed Kubernetes clusters. This ensures low-latency access for users in different regions while providing fault tolerance and high availability through redundant deployments across clusters.

- Resource Optimization and Scaling
Karmada enables efficient resource utilization by dynamically scaling application instances across multiple clusters based on real-time demand. This helps organizations minimize infrastructure costs while ensuring optimal performance and responsiveness for their applications.

- Disaster Recovery and High Availability
Karmada supports disaster recovery strategies by replicating critical workloads across multiple clusters. In the event of a cluster failure or outage, Karmada automatically redirects traffic to healthy clusters, minimizing downtime and preserving business continuity.

- Multi-Tenancy and Isolation
Karmada allows organizations to implement multi-tenancy models by segregating workloads from different teams or departments across distinct clusters. This enhances security and isolation while providing centralized management and visibility through a unified control plane.\>

- Blue-Green and Canary Deployments
With Karmada, organizations can implement advanced deployment strategies such as blue-green and canary deployments across multiple clusters. This enables risk-free testing of new features and versions before rolling them out to production, ensuring a smooth and seamless user experience.


## Architecture overview

Below are architecture diagrams of a sample Karamada based Cluster architecture with parent and managed clusters and its centralized containerized application deployment process to those clusters. 


### Architecture diagram

More specifically, you can find below an architecture diagram of a sample Karamada based Cluster architecture with parent and managed clusters and its centralized containerized application deployment process to those clusters. 


<!-- {% include image.html file="mcm_eksarmada_images/IG_Figure1.png" alt="architecture" %} -->
<!--  {% include image.html file="sql_etl_spark_eks_images/solution-architecture-for-implementation-guide.jpg" alt="Solution Architecture" %} -->

{% include image.html file="mcm_ekskarmada_images/karmada_ref_architecture1.jpg" alt="Karmada cluster architecture" %}

*Figure 1: Multi-cluster application management with EKS and Karmada on AWS - managed clusters*

{% include image.html file="mcm_ekskarmada_images/karmada_ref_architecture2.jpg" alt="Karmada application deployment architecture" %}

*Figure 2: Multi-cluster application management with EKS and Karmada on AWS - application deployment*

In a similar fashion you can:

Deploy applications on multiple Amazon EKS clusters that provide a highly available environment
Create the infrastructure that caters for workloads compliant with local regulation about data residency

### Architecture steps

**Karmada Clusters Architecture Steps (figure 1) :**

1. User interacts with the Karmada API server (part of Karmada Control Plane) using the kubectl utility and a Network Load Balancer as the endpoint
2. A Network Load Balancer provides SSL termination and acts as a proxy for Karmada services running on Amazon EKS parent cluster
3. The Karmada Control Plane exposes the Karmada API via its API server in addition to the Kubernetes API, which receives calls for Kubernetes and Karmada management tasks
4. Karmada runs several components on the Amazon EKS compute nodes. To keep records of API objects and state, its API server uses its own etcd database deployment.
5. Karmada etcd database uses EBS volumes attached to compute nodes/EC2 instances to keep its state and consistency. All state changes and updates get persisted in EBS volumes across all EC2 compute nodes that host etcd pods.

**Karmada Application Deployment Architecture Steps (figure 2):**

1. User interacts with the Karmada API server (part of Karmada Control Plane) using the kubectl CLI with Karmada plugin. User sends a command for multiple clusters, ex. a multi-region deployment of NGNIX application with  equal weight across two member EKS clusters
2. The Karmada Control Plane maintains the status and state of all member EKS clusters. Upon receiving the user request it interprets the requirement and instructs member clusters accordingly. E.G. run an NGINX deployment in each member cluster
3. The EKS cluster member 1 receives instructions from Karmada Control Plane to deploy and run an NGINX container application deployment
4. The EKS cluster member 2 receives instructions from Karmada Control Plane to deploy and run an NGINX container application deployment
5. The EKS Karmada Control Plane cluster checks application deployment status on the member clusters and updates state in its etcd database
6. User validates the status of multi-cluster application deployment communicating with Karmada Control Plane via kubectl Karmada CLI


### AWS services in this Guidance

| **AWS service**  | Description |
|-----------|------------|
| [Amazon Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/){:target="_blank"}|Core service - The EKS service is used to host the Karmada solution that uses containers. In essece it is an extension of the Kubernetes API.|
| [Amazon Elastic Compute Cloud (EC2)](https://aws.amazon.com/ec2/){:target="_blank"}|Core service - The EC2 service is used as the host of the containers needed for this solution.|
| [Amazon Network Load Balancer (NLB)](https://aws.amazon.com/elasticloadbalancing/network-load-balancer/){:target="_blank"}|Supporting service - The NLB acts as a proxy for Karmada services running on Amazon EKS parent cluster. More specifically, it is used so that traffic can be distributed to the Karmada pods. The load balancer is the entry point to interact with the Karmada API server and forwards traffic to any healthy backend node making sure that the solution will still be working in case of any single node or availability zone failure.|
| [Amazon Elastic Block Store (EBS)](https://aws.amazon.com/ebs){:target="_blank"}|Supporting service - The EBS volumes are used by the Karmada etcd database attached to compute nodes/EC2 instances to keep its state and consistency. All state changes and updates get persisted in EBS volumes across all EC2 compute nodes that host etcd pods.|
| [AWS Identity and Access Management (IAM)](https://aws.amazon.com/iam/){:target="_blank"}|Supporting service - The AWS IAM service is used for the creation of an IAM user with adequate permissions to create and delete Amazon EKS clusters access.|

## Plan your deployment

This solution assumes the existence of two Amazon EKS clusters that will be member clusters of the Karmada cluster. However, as Karmada is an extension to the native Kubernetes API, you can extend this solution and expand the cluster federation with other kubernetes deployments, not necessarily Amazon EKS.

### Cost 

You are responsible for the cost of the AWS services used while running this Guidance. As of February 2024, the cost for running this guidance with the default settings in the US-East (N. Virginia) is $0.10 per hour for each Amazon EKS cluster you have created. On top of this you have to take into account the costs incurred by the AWS resources used for the EKS cluster (e.g. Amazon Elastic Compute Cloud (EC2) Instances, Amazon Elastic Block Store (EBS) volumes etc).

Refer to the pricing webpage for each AWS service used in this Guidance.

Suggest you keep this boilerplate text:

We recommend creating a <a href="https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-create.html" target="_blank">budget</a>
 through [AWS Cost Explorer](http://aws.amazon.com/aws-cost-management/aws-cost-explorer/){:target="_blank"} to help manage costs. Prices are subject to change. For full details, refer to the pricing webpage for each AWS service used in this Guidance.

### Sample cost table

The following table provides a sample cost breakdown for deploying this Guidance with the default parameters in the US East (N. Virginia) Region for one month.

| **AWS service**  | Dimensions | Cost \[USD\] |
|-----------|------------|------------|
| Amazon EKS | 1 cluster | \$ 73\/month |
| Amazon ELB | 1 Network Load Balancer | \$ 16.425\/month + 4.38\/NLCU\/month <sup>*</sup>|
| Amazon EBS | 5GB worth of EBS disk gp3 type | \$ 5.14\/month |
| Amazon EC2 | cluster nodes | \$ depends on the instance type |
| NAT Gateway| 1 instance | \$ 32.85\/month + 32.85\/GB processed | 

<!--StartFragment-->
 Note
--
> <sup>*</sup> An NLCU measures the dimensions on which the Network Load Balancer processes your traffic (averaged over an hour). The three dimensions measured are:  
> - New connections or flows: Number of newly established connections/flows per second. Many technologies (HTTP, WebSockets, etc.) reuse Transmission Control Protocol (TCP) connections for efficiency. The number of new connections is typically lower than your request or message count.
> - Active connections or flows: Peak concurrent connections/flows, sampled minutely.  
> - Processed bytes: The number of bytes processed by the load balancer in GBs. 
You are charged only on one of the three dimensions that has the highest usage for the hour.
<!--EndFragment-->


## Security

When you build systems on AWS infrastructure, security responsibilities are shared between you and AWS. This [shared responsibility model](https://aws.amazon.com/compliance/shared-responsibility-model/){:target="_blank"} reduces your operational burden because AWS operates, manages, and controls the components including the host operating system, the virtualization layer, and the physical security of the facilities in which the services operate. For more information about AWS security visit [AWS Cloud Security](http://aws.amazon.com/security/){:target="_blank"}.

For the purposes of this solution, you have to leverage the use of VPC security groups and IAM users and roles. More specifically, a rule in Security Group that allows incoming traffic from the TCP port 32443 is created automatically with the use of the Amazon Elastic Load Balancer (NLB). This Security Group is attached to all the nodes of the Karmada cluster. 
Also, you need an IAM user with adequate permissions to create and delete Amazon EKS clusters access.

### Supported AWS Regions

The AWS services used for this guidance are supported in all AWS available regions.

### Quotas

Service quotas, also referred to as limits, are the maximum number of service resources or operations for your AWS account.

### Quotas for AWS services in this Guidance

Make sure you have sufficient quota for each of the services implemented in this solution. For more information, see [AWS service quotas](https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html){:target="_blank"}.

To view the service quotas for all AWS services in the documentation without switching pages, view the information in the [Service endpoints and quotas](https://docs.aws.amazon.com/general/latest/gr/aws-general.pdf#aws-service-information){:target="_blank"} page in the PDF instead.

## Deploy the Guidance in an automated way 
There are two ways to deploy this solution automatically. The first approach is an opinionated method leveraging aws cli scripts and the second approach makes use of the AWS Cloud Development Kit (CDK) 

### Opinionated method with the use of aws cli script
To use this option, please check here

### Method with the use of AWS CDK 
To use this option, please check here

## Deploy the Guidance in a manual step-by-step procedure

If you want to manually deploy the solution step-by-step so that you  gain insights on the actual procedured, please follow the steps below

### Prerequisites

For the purspose of this guide you need to have already in place the following prerequisites:

- An active [AWS Account](https://docs.aws.amazon.com/accounts/latest/reference/welcome-first-time-user.html){:target="_blank"} to deploy the main Amazon EKS cluster
- Αn [Amazon VPC](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/gsg_create_vpc.html){:target="_blank"} with (a) three public [subnets](https://docs.aws.amazon.com/vpc/latest/userguide/create-subnets.html){:target="_blank"} and enabled the option to auto-assign public IPv4 adressess, and three private subnets and disabled the option to auto-assign public IPv4 adressess across three different availability zones
- An [Internet Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html){:target="_blank"} to allow Internet access for all cluster nodes
- A [security group](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/working-with-security-groups.html){:target="_blank"} to allow inbound traffic to TCP port 32443 ???? -> Τhis may not be needed
- An [EC2 instance]([https://aws.amazon.com/ec2/]){:target="_blank"} to deploy, access and manage the main cluster from. We will call this a management instance 
- A [NAT gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html){:target="_blank"} with default route from private subnets to allow Internet access for all cluster nodes.
- A [user with administrator access](https://docs.aws.amazon.com/streams/latest/dev/setting-up.html){:target="_blank"} and an [Access key/Secret access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html){:target="_blank"} to configure [AWS Command Line Interface(AWS CLI)](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html){:target="_blank"} 

### Deployment process overview

Before you launch the Guidance, review the cost, architecture, security, and other considerations discussed in this guide. Follow the step-by-step instructions in this section to configure and deploy the Guidance into your account.

**Time to deploy:** Approximately 30-60 minutes, depending on the number of cluster deployed.

### Write Procedures using a "Step-by-Step" Format

Preparation

Logon to the management EC2 instance that resides in the same VPC you created for the purposes of this project. Run the following commands:

1. Install and configure the AWS CLI version 2.

```bash
cd /tmp
curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
```

2. Install the eksctl utility to deploy and manage Amazon EKS clusters in your account.

```bash
cd /tmp
curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
tar -xzf eksctl_Linux_amd64.tar.gz -C /tmp && rm eksctl_Linux_amd64.tar.gz
chmod +x eksctl
sudo mv /tmp/eksctl /usr/local/bin
```

3. Install the kubectl utility

```bash
cd /tmp
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.26.2/2023-03-17/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv kubectl /usr/local/bin
```

4. Install the jq utility

```bash
sudo yum install jq
```

5. Disable [AWS Managed temporary credentials](https://docs.aws.amazon.com/cloud9/latest/user-guide/credentials.html) in your AWS Cloud9 environment

```bash
aws cloud9 update-environment --environment-id $C9_PID --managed-credentials-action DISABLE
rm -vf ${HOME}/.aws/credentials
```

### Deploy Amazon EKS main cluster for Karmada

After you complete the preliminary steps you proceed with the deployment of an Amazon EKS cluster that will host Karmada.

1. Open the AWS Cloud9 terminal
2. Configure the AWS CLI, providing your user's Access Key and Secrete Access Key

```bash
  aws configure
AWS Access Key ID [None]: <Access_Key_ID>
AWS Secret Access Key [None]: <Secret_Access_Key>
Default region name [None]: <region_where_VPC_resides>
Default output format [None]: 
```

3. Populate the environment variable KARMADA_VPCID with the VPC id of the VPC that you want to deploy the Karmada cluster (eg. for a VPC with the name tag Karmada_VPC replace <name_of_VPC_you_have_created> with Karmada_VPC).

```bash
KARMADA_VPCID=$(aws ec2 describe-vpcs --filter "Name=tag:Name,Values=*<name_of_VPC_you_have_created>*" --query "Vpcs[].VpcId" --output text)
```

4. Get the list of private subnets for this VPC in environment variable KARMADA_PRIVATESUBNETS.

```bash
KARMADA_PRIVATESUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${KARMADA_VPCID}" --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' | jq -r '. | @csv')
```

5. Get public subnets for this VPC in environment variable KARMADA_PUBLICSUBNETS.

```bash
KARMADA_PUBLICSUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${KARMADA_VPCID}" --query 'Subnets[?MapPublicIpOnLaunch==`true`].SubnetId' | jq -r '. | @csv')
```

6. Define three environment variables to define the account id, the AWS region to deploy the Amazon EKS main cluster and the preferred cluster name.

_Note: The KARMADA_REGION variable denoted the region actually used by the CLI regardless of whether environment variables are or are not set_

```bash
KARMADA_ACCOUNTID=$(aws sts get-caller-identity --query "Account" --output text)
KARMADA_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
KARMADA_CLUSTERNAME=karmada-parent
```

7. Deploy an Amazon EKS cluster with three nodes
_*Note*_: *This operation will take a few minutes*

```bash
eksctl create cluster --nodes 3 --nodes-min 3 --nodes-max 3 \
--region ${KARMADA_REGION} \
--instance-prefix karmadaeks \
--vpc-private-subnets ${KARMADA_PRIVATESUBNETS} \
--vpc-public-subnets ${KARMADA_PUBLICSUBNETS} \
--name ${KARMADA_CLUSTERNAME}
```

_Note: In order to allow AWS Management console access to the cluster, if you connect with different than the cli user, then execute the following command replacing where applicable with your actual username (KARMADA_ACCOUNTID is the account ID of your AWS account, as noted above)._

```bash
eksctl create iamidentitymapping \
--cluster ${KARMADA_CLUSTERNAME} \
--arn "arn:aws:iam::${KARMADA_ACCOUNTID}:user/<your_username>" \
--username <your_username> \
--group system:masters --no-duplicate-arns
```

8. Deploy the EBS add-on
  
 - In case it does not exist already, associate the IAM OIDC provider

```bash
eksctl utils associate-iam-oidc-provider \
--region=${KARMADA_REGION} \
--cluster=${KARMADA_CLUSTERNAME} \
--approve
```

 - Create the necessary IAM service account for the EBS CSI controller

```bash
eksctl create iamserviceaccount \
--cluster ${KARMADA_CLUSTERNAME} \
--region ${KARMADA_REGION} \
--name ebs-csi-controller-sa \
--namespace kube-system  \
--attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
--approve --role-only \
--role-name AmazonEKS_EBS_CSI_DriverRole
```

 - Deploy the EBS add-on

```bash
eksctl create addon \
--cluster ${KARMADA_CLUSTERNAME} \
--region ${KARMADA_REGION} \
--name aws-ebs-csi-driver \
--service-account-role-arn arn:aws:iam::${KARMADA_ACCOUNTID}:role/AmazonEKS_EBS_CSI_DriverRole \
--force
```

 - Create the configuration for a storage class for the EBS storage.

```bash
cat > ebs-sc.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
EOF
```

 - Create the storage class

```bash
kubectl apply -f ./ebs-sc.yaml
```

__Important__: In case this commands fails with access denied errors, you may need to remove the 'aws_session_token =' line from the ~/.aws.credentials file.*

9. Verify the operation of the Amazon EKS cluster

Verify cluster resources and status either by using the AWS Management Console or the kubectl utility. Some of the things to check.

```bash
kubectl get svc -A
kubectl get pods -A
kubectl get sc -A
kubectl describe sc ebs-sc
kubectl get nodes -A -o wide
```

For your convenience below is the sample output of the commands above for our testing cluster*

 - Get all services

```bash
$ kubectl get svc -A
NAMESPACE     NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)         AGE
default       kubernetes   ClusterIP   172.20.0.1    <none>        443/TCP         28m
kube-system   kube-dns     ClusterIP   172.20.0.10   <none>        53/UDP,53/TCP   28m
```

 - Get all pods

```bash
$ kubectl get pods -A
NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE
kube-system   aws-node-5dj6f                        1/1     Running   0          20m
kube-system   aws-node-fsgcf                        1/1     Running   0          20m
kube-system   aws-node-j8shd                        1/1     Running   0          20m
kube-system   coredns-5947f47f5f-c2vkh              1/1     Running   0          28m
kube-system   coredns-5947f47f5f-m97dx              1/1     Running   0          28m
kube-system   ebs-csi-controller-64d647d966-96gbm   6/6     Running   0          115s
kube-system   ebs-csi-controller-64d647d966-mtvrf   6/6     Running   0          115s
kube-system   ebs-csi-node-6cccm                    3/3     Running   0          115s
kube-system   ebs-csi-node-9gvr5                    3/3     Running   0          115s
kube-system   ebs-csi-node-nrnqz                    3/3     Running   0          115s
kube-system   kube-proxy-2xqfw                      1/1     Running   0          20m
kube-system   kube-proxy-pqwkb                      1/1     Running   0          20m
kube-system   kube-proxy-xhpl4                      1/1     Running   0          20m
```

 - Get all storage classes

```bash
$ kubectl get sc -A
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
ebs-sc          ebs.csi.aws.com         Delete          WaitForFirstConsumer   false                  44s
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  28m
```

 - Get details for the storage class ebs-sc

```bash
$ kubectl describe sc ebs-sc
Name: ebs-sc
IsDefaultClass: No
Annotations: [kubectl.kubernetes.io/last-applied-configuration={{"apiVersion":"storage.k8s.io/v1","kind":"StorageClass","metadata":{"annotations":{},"name":"ebs-sc"},"parameters":{"type":"gp3"},"provisioner":"ebs.csi.aws.com","volumeBindingMode":"WaitForFirstConsumer"}](http://kubectl.kubernetes.io/last-applied-configuration)
Provisioner: [ebs.csi.aws.com](http://ebs.csi.aws.com/)
Parameters: type=gp3
AllowVolumeExpansion: <unset>
MountOptions: <none>
ReclaimPolicy: Delete
VolumeBindingMode: WaitForFirstConsumer
Events: <none>
```

 - Get infortmation for all cluster nodes

```bash
$ kubectl get nodes -A -o wide
NAME                                        STATUS   ROLES    AGE   VERSION                INTERNAL-IP   EXTERNAL-IP     OS-IMAGE         KERNEL-VERSION                 CONTAINER-RUNTIME
ip-10-0-2-204.eu-west-1.compute.internal    Ready    <none>   21m   v1.22.17-eks-0a21954   10.0.2.204    <public_IP_A>   Amazon Linux 2   <public_IP_X>.amzn2.x86_64   docker://20.10.23
ip-10-0-20-99.eu-west-1.compute.internal    Ready    <none>   21m   v1.22.17-eks-0a21954   10.0.20.99    <public_IP_B>   Amazon Linux 2   <public_IP_X>.amzn2.x86_64   docker://20.10.23
ip-10-0-34-232.eu-west-1.compute.internal   Ready    <none>   21m   v1.22.17-eks-0a21954   10.0.34.232   <public_IP_C>   Amazon Linux 2   <public_IP_X>.amzn2.x86_64   docker://20.10.23
```

### Deploy Karmada

You are now ready to deploy Karmada. This will allow you to extend the capabilities of your new EKS cluster with the extra Karmada functionality. By design, Karmada uses an internal etcd database to keep its own state, thus in order to deploy a resilient Karmada cluster you need an odd number of nodes to run Karmada workloads, which is three (3) in this case. You also need a load balancer to distribute the load across all available Karmada pods and continue working in case of any single node or availability zone failure.

1. Install the karmada plugin for kubectl.

```bash
curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo bash -s kubectl-karmada
```

2. Initialize karmada using the external IP address of the first cluster node as the advertised karmada API server endpoint. You should also add the wildcard domain name for AWS load balancers to the API server certificate.

_Note: In order to avoid issues running the following command you have to allow incoming traffic for TCP port 32443 in the security group attached to the cluster node. If necessary add the appropriate security group that allows incoming traffic for TCP port 32443 to all 3 nodes of the Karmada cluster._

```bash
 sudo -E env "PATH=$PATH" kubectl karmada init --karmada-apiserver-advertise-address $(kubectl get nodes -o jsonpath="{.items[0].status.addresses[?(@.type=='ExternalIP')].address}") --karmada-apiserver-replicas 3 --etcd-replicas 3 --etcd-storage-mode PVC --storage-classes-name ebs-sc --cert-external-dns="*.elb.${KARMADA_REGION}.amazonaws.com" --kubeconfig /home/ec2-user/.kube/config
```

When the initialization is complete, karmada displays important information on how to join member cluster.

__Important:__ Note the security token and the CA cert hash. You will need them upon registering other Amazon EKS clusters to Karmada.

```bash
(... output text ...)
------------------------------------------------------------------------------------------------------
 █████   ████   █████████   ███████████   ██████   ██████   █████████   ██████████     █████████
░░███   ███░   ███░░░░░███ ░░███░░░░░███ ░░██████ ██████   ███░░░░░███ ░░███░░░░███   ███░░░░░███
 ░███  ███    ░███    ░███  ░███    ░███  ░███░█████░███  ░███    ░███  ░███   ░░███ ░███    ░███
 ░███████     ░███████████  ░██████████   ░███░░███ ░███  ░███████████  ░███    ░███ ░███████████
 ░███░░███    ░███░░░░░███  ░███░░░░░███  ░███ ░░░  ░███  ░███░░░░░███  ░███    ░███ ░███░░░░░███
 ░███ ░░███   ░███    ░███  ░███    ░███  ░███      ░███  ░███    ░███  ░███    ███  ░███    ░███
 █████ ░░████ █████   █████ █████   █████ █████     █████ █████   █████ ██████████   █████   █████
░░░░░   ░░░░ ░░░░░   ░░░░░ ░░░░░   ░░░░░ ░░░░░     ░░░░░ ░░░░░   ░░░░░ ░░░░░░░░░░   ░░░░░   ░░░░░
------------------------------------------------------------------------------------------------------
Karmada is installed successfully.
 
Register Kubernetes cluster to Karmada control plane.
 
Register cluster with 'Push' mode
 
Step 1: Use "kubectl karmada join" command to register the cluster to Karmada control plane. --cluster-kubeconfig is kubeconfig of the member cluster.
(In karmada)~# MEMBER_CLUSTER_NAME=$(cat ~/.kube/config  | grep current-context | sed 's/: /\n/g'| sed '1d')
(In karmada)~# kubectl karmada --kubeconfig /etc/karmada/karmada-apiserver.config  join ${MEMBER_CLUSTER_NAME} --cluster-kubeconfig=$HOME/.kube/config
 
Step 2: Show members of karmada
(In karmada)~# kubectl --kubeconfig /etc/karmada/karmada-apiserver.config get clusters
 
Register cluster with 'Pull' mode
 
Step 1: Use "kubectl karmada register" command to register the cluster to Karmada control plane. "--cluster-name" is set to cluster of current-context by default.
(In member cluster)~# kubectl karmada register <public_IP>:32443 --token <security-token> --discovery-token-ca-cert-hash <ca-cert-hash>
 
Step 2: Show members of karmada
(In karmada)~# kubectl --kubeconfig /etc/karmada/karmada-apiserver.config get clusters
```

3. Prepare the deployment of a [Network Load Balancer](https://aws.amazon.com/elasticloadbalancing/network-load-balancer/) to make the Karmada API server highly available. The load balancer is the entry point to interact with the Karmada API server and forwards traffic to any healthy backend node.

```bash
cat <<EOF > loadbalancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: karmada-service-loadbalancer
  namespace: karmada-system
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-name: karmada-lb
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
spec:
  type: LoadBalancer
  selector:
    app: karmada-apiserver
  ports:
    - protocol: TCP
      port: 32443
      targetPort: 5443
EOF
```

4. Deploy the Network Load Balancer

```bash
kubectl apply -f loadbalancer.yaml
```

5. Get the load balancer's hostname to use with Karmada.

```bash
KARMADA_LB=$(kubectl get svc -n karmada-system karmada-service-loadbalancer -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

### Join member cluster

As of now you have deployed an EKS cluster with a highly avaliable Karmada API server and a Network Load Balancer to handle incoming traffic. The next step is to register you member clusters with Karmada. To do that Karmada offers two different methods, Push or Pull. Refer to [Karmada documentation](https://karmada.io/docs/userguide/clustermanager/cluster-registration) for more info.

At the moment Karmada has a [limitation](https://github.com/karmada-io/karmada/blob/6089fa379427bda937cfe739d841e477f5ae6592/pkg/apis/cluster/validation/validation.go#L18) and the cluster name cannot be more than 48 chars. This is a blocker for the vast majority of Amazon EKS clusters as the cluster name is the ARN which is at least 44 characters. In order to overcome that we have to explicitly define the name of the member cluster to something less than 48 chars.

It is recommended to use the friendly name of the EKS cluster and use **only** small Latin characters and numbers (no spaces, no capital letters, no symbols etc). More specifically, the name must consist of lower case alphanumeric characters or '-', and must start and end with an alphanumeric character (e.g. 'my-name', or '123-abc', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?'

Login to the management host for your member cluster, or change to the appropriate context so that kubectl communicates with the required member cluster. Edit directly the ~/.kube/config file to change the cluster name for the desired member cluster. Ensure that you have a __backup__ of the file before edit. Locate the cluster and context sections and alter the cluster named accordingly. In the following example you can see a full snippet of a config file for the cluster with name _myclustername.<region>.eksctl.io_ 

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: 
    (few lines of certificate data)
    server: https://<id>.<region>.eks.amazonaws.com
  name: myclustername.<region>.eksctl.io
contexts:
- context:
    cluster: myclustername.<region>.eksctl.io
    user: user@myclustername.<region>.eksctl.io
  name: user@myclustername.<region>.eksctl.io
current-context: myclustername.<region>.eksctl.io
```

Change the appropriate entries (clusters -> cluster -> name, contexts -> context -> cluster, context -> name, current-context) with a friendly and compliant name such as _myclustername_.

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: 
    (few lines of certificate data)
    server: https://<id>.<region>.eks.amazonaws.com
  name: myclustername
contexts:
- context:
    cluster: myclustername
    user: user@myclustername.<region>.eksctl.io
  name: myclustername
current-context: myclustername
```

##### Register cluster with pull mode

Ensure you are logged in the Karmada management host and that you have the member clusters configured and accessible with the _kubectl_ utility. As an example we have three cluster that we are managing, two in Frankfurt region (eu-central-1) and one in the N. Virginia region (us-east-1).

```bash
user@bastion:~$ kubectl config get-contexts
CURRENT   NAME                                  CLUSTER                          AUTHINFO                                NAMESPACE
*         user@EKSUSMGT01.us-east-1.eksctl.io   EKSUSMGT01.us-east-1.eksctl.io   user@EKSUSMGT01.us-east-1.eksctl.io
          ekseucl01                             ekseucl01                        user@EKSEUCL01.eu-central-1.eksctl.io
          ekseucl02                             ekseucl02                        user@EKSEUCL02.eu-central-1.eksctl.io
          eksuscl01                             eksuscl01                        user@EKSUSCL01.us-east-1.eksctl.io
```

1. Change context to the cluster you are registering to karmada

```bash
kubectl config use-context ekseucl01
```

2. Register the cluster to karmada

```bash
user@bastion:~$ sudo -E env "PATH=$PATH" kubectl karmada --kubeconfig /etc/karmada/karmada-apiserver.config join ekseucl01 --cluster-kubeconfig=$HOME/.kube/config
cluster(ekseucl01) is joined successfully
```

3. Repeat the previous steps for the other clusters as well

4. Check karmada cluser status

```bash
user@bastion:~$ sudo kubectl --kubeconfig /etc/karmada/karmada-apiserver.config get clusters
NAME        VERSION               MODE   READY   AGE
ekseucl01   v1.27.6-eks-f8587cb   Push   True    9h
ekseucl02   v1.27.6-eks-f8587cb   Push   True    9h
eksuscl01   v1.27.6-eks-f8587cb   Push   True    9h
```

At this point you have joined the clusters to Karmada and you are able to access all [Karmada features](https://karmada.io/docs/key-features/features).

##### Register cluster with push mode

The registration of a member cluster with push mode requires accessing a cluster from a host that has no karmada components install. This method also deploys in your cluster the karmada-agent so that it can push information and commands from the Karmada API server. You also have to make sure that your cluster and the management host can access the Karmada API server (ex. over internet, through VPC peering, etc).

1. Login to the host that you can access the member cluster

2. Install the karmada plugin

```bash
curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo bash -s kubectl-karmada
```

3. Run the command below to register this cluster with Karmada, using the load balancer IP you have from previous step and also the token and certification hash you have noted also before during the Karmada API installation.

```bash
kubectl karmada register ${KARMADA_LB}:32443 \
--token <security-token> \
--discovery-token-ca-cert-hash <ca-cert-hash> \
--cluster-name=<name_of_cluster_member>
```

At this point you have joined the cluster to Karmada and you are able to access all [Karmada features](https://karmada.io/docs/key-features/features). 

### Multi cluster scheduling with Karmada

Karmada enables many advanced capabilities such as [multi-cluster scheduling](https://karmada.io/docs/userguide/scheduling/resource-propagating), [multi-cluster failover](https://karmada.io/docs/userguide/failover/failover-overview) or [autoscaling across different cluster](https://karmada.io/docs/userguide/autoscaling/federatedhpa). 

As an example at this point, assume you have three clusters registered with Karmada. Two in in eu-central-1 region and one in us-east-1. You can deploy a simple nginx application that will span across all three clusters. You also want to equally spread the capacity across cluster in Europe and North America. Since you have two clusters in eu-central-1 region, you want each to have 25% of the pods, thus you give a weight 1. For the us-east-1 region you want to have 50% of pods in the only cluster available, thus you give a weight 2.

1. Create a propagation policy that will give the required weights to different clusters. 

```yaml
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: sample-propagation
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      name: nginx
  placement:
    clusterAffinity:
      clusterNames:
        - ekseucl01
        - ekseucl02
        - eksuscl01
    replicaScheduling:
      replicaDivisionPreference: Weighted
      replicaSchedulingType: Divided
      weightPreference:
        staticWeightList:
          - targetCluster:
              clusterNames:
                - ekseucl01
                - ekseucl02
            weight: 1
          - targetCluster:
              clusterNames:
                - eksuscl01
            weight: 2
```

2. If necessary switch to the right context so that you run commands against the Karmada management cluster

```bash
user@bastion:~$ kubectl config use-context user@EKSUSMGT01.us-east-1.eksctl.io
Switched to context "user@EKSUSMGT01.us-east-1.eksctl.io".
karmadapets@ip-172-16-11-165:~$ kubectl config get-contexts
CURRENT   NAME                                  CLUSTER                          AUTHINFO                                NAMESPACE
*         user@EKSUSMGT01.us-east-1.eksctl.io   EKSUSMGT01.us-east-1.eksctl.io   user@EKSUSMGT01.us-east-1.eksctl.io
          ekseucl01                             ekseucl01                        user@EKSEUCL01.eu-central-1.eksctl.io
          ekseucl02                             ekseucl02                        user@EKSEUCL02.eu-central-1.eksctl.io
          eksuscl01                             eksuscl01                        user@EKSUSCL01.us-east-1.eksctl.io
```

3. Apply the propagation policy

```bash
user@bastion:~$ sudo kubectl --kubeconfig /etc/karmada/karmada-apiserver.config create -f propagation-policy.yaml
propagationpolicy.policy.karmada.io/sample-propagation created
```

4. Create the nginx deployment with 12 replicas. 

```bash
user@bastion:~$ sudo kubectl --kubeconfig /etc/karmada/karmada-apiserver.config create deployment nginx --image nginx --replicas=12
deployment.apps/nginx created
```

5. Check that you get 6 replicas in North America and 3 replicas in each cluster in Europe.

```bash
user@bastion:~$ kubectl config use-context eksuscl01
Switched to context "eksuscl01".
user@bastion:~$ kubectl get pod -l app=nginx
NAME                     READY   STATUS    RESTARTS   AGE
nginx-77b4fdf86c-c5f6b   1/1     Running   0          2m39s
nginx-77b4fdf86c-g5fnr   1/1     Running   0          2m39s
nginx-77b4fdf86c-kw42g   1/1     Running   0          2m39s
nginx-77b4fdf86c-qcvt2   1/1     Running   0          2m39s
nginx-77b4fdf86c-r5phj   1/1     Running   0          2m39s
nginx-77b4fdf86c-rns48   1/1     Running   0          2m39s

user@bastion:~$ kubectl config use-context ekseucl01
Switched to context "ekseucl01".
user@bastion:~$ kubectl get pod -l app=nginx
NAME                     READY   STATUS    RESTARTS   AGE
nginx-77b4fdf86c-2zd49   1/1     Running   0          4m40s
nginx-77b4fdf86c-5pcvf   1/1     Running   0          4m40s
nginx-77b4fdf86c-c7w8q   1/1     Running   0          4m40s

user@bastion:~$ kubectl config use-context ekseucl02
Switched to context "ekseucl02".
user@bastion:~$ kubectl get pod -l app=nginx
NAME                     READY   STATUS    RESTARTS   AGE
nginx-77b4fdf86c-bhftk   1/1     Running   0          4m48s
nginx-77b4fdf86c-bp4jr   1/1     Running   0          4m48s
nginx-77b4fdf86c-txjk5   1/1     Running   0          4m48s
```

## Uninstall the Guidance

To remove the Karmada and the related resources, run the following command to delete the parent Amazon EKS cluster you have deployed for Karmada.

```bash
eksctl delete cluster —name ${KARMADA_CLUSTERNAME}
``````

_*Note*_: *Check [this link](https://karmada.io/docs/userguide/clustermanager/cluster-registration/#unregister-cluster){:target="_blank"} how to unregister the cluster.*


*Automated way through the use of a cli script*

*Automated way through CDK*

### Related resources

This solution is based on Open, Multi-Cloud, Multi-Cluster Kubernetes Orchestration Management system called [Karmada](https://karmada.io/){:target="_blank"}

### Contributors

The following individuals contributed to this document:

- Dimitrios Papageorgiou, Sr SA AWS (dpapageo@amazon.com)
- Alexandros Soumplis, Sr SA AWS (soumplis@amazon.com)
- Konstantinos Tzouvanas, Sr SA AWS (ktzouvan@amazon.com)
- Pavlos Kaimakis, Sr SA AWS (pkaim@amazon.com)
- Daniel Zilberman, Sr SA AWS Tech Solutions Team (dzilberm@amazon.com)

## Notices

Customers are responsible for making their own independent assessment of the information in this document. This document: 
(a) is for informational purposes only, 
(b) represents AWS current product offerings and practices, which are subject to change without notice, and
(c) does not create any commitments or assurances from AWS and its affiliates, suppliers or licensors. 

AWS products or services are provided "as is" without warranties, representations, or conditions of any kind, whether express or implied. AWS responsibilities and liabilities to its customers are controlled by AWS agreements, and this document is not part of, nor does it modify, any agreement between AWS and its customers.
