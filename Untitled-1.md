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

The 'Multi-cluster application management with EKS and Karmada on AWS' helps you with the deployment and use of the open source project [Karmada](https://karmada.io/) for [Kubernetes](https://kubernetes.io/) multi-cluster management. Karmada is a Kubernetes management system with advanced scheduling capabilities, that enables you to run your cloud-native applications across multiple Kubernetes clusters and clouds, with no changes to your applications. With this Guidance you will be able to setup a federated Kubernetes environment in Amazon Web Services (AWS) Cloud using [Amazon Elastic Kubernetes Service (Amazon EKS)](https://aws.amazon.com/eks/). The purpose of this guidance is to provide both step-by-step instructions and also an opinionated automation script, to deploy an [Amazon EKS](https://aws.amazon.com/eks/) cluster that will host Karmada control plane to act as the parent cluster for multi-cluster management. You also have the option to use existing Amazon EKS clusters or [create new](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html) Amazon EKS clusters that will act as member clusters. With this Guidance you will also have a sample workload distributed among the member clusters to demonstrate a portion of the capabilities of Karmada.

### Features and benefits

The 'Multi-cluster application management with EKS and Karmada on AWS' guidance provides the following features:

For each feature, add a succinct phrase that defines the feature
explaining the benefit of the feature from a user\'s perspective.

 It allows you to have central management since it is cluster location agnostic and support clusters in public cloud, on-prem or edge. It is compatible with the Kubernetes Native API and enables seamless integration of existing Kubernetes tool chain. It also provides out of the box, built-in policy sets for multiple scenarios such as active-active, remote disaster recovery and geo redundancy. You can also use advanced scheduling policies to achieve cluster affinity, multi-cluster split or rebalance and multi-dimension high availability on the level of Region, Availability Zone, Cluster or Provider.

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

Cluster location agnostic; Support clusters in public cloud, on-prem or edge


\<Feature 1 definition and benefit \>

### Use cases

For each use case, add a phrase that defines the use case..

\<Use case 1 definition\>

\<Use case explanation Use case explanation Use case explanation Use
case explanation Use case explanation Use case explanation Use case
explanation.\>

## Architecture overview


This section provides a reference implementation architecture diagram
for the components deployed with this Guidance.

### Architecture diagram

When you are creating your diagram, use the [*official and approved
service icons*](https://aws.amazon.com/architecture/icons/){:target="_blank"} and build
your diagram in PowerPoint and share the source file with your technical
writer. For the official AWS service names, reference the [*Service
Names
wiki*](https://w.amazon.com/bin/view/AWSDocs/editing/service-names){:target="_blank"}.


<!-- {% include image.html file="mcm_eksarmada_images/IG_Figure1.png" alt="architecture" %} -->
<!--  {% include image.html file="sql_etl_spark_eks_images/solution-architecture-for-implementation-guide.jpg" alt="Solution Architecture" %} -->

{% include image.html file="mcm_ekskarmada_images/karmada_ref_architecture1.jpg" alt="Karmada cluster architecture" %}

*Figure 1: Multi-cluster application management with EKS and Karmada on AWS - managed clusters*

{% include image.html file="mcm_ekskarmada_images/karmada_ref_architecture2.jpg" alt="Karmada application deployment architecture" %}

*Figure 2: Multi-cluster application management with EKS and Karmada on AWS - application deployment*

### Architecture steps

Add numbers in the architecture diagram and explain each step. If the icon is depicted in the diagram, it needs to be mentioned with the
corresponding step.

**Karmada Clusters Architecture Steps:**

1. User interacts with the Karmada API server (part of Karmada Control Plane) using the kubectl utility and a Network Load Balancer as the endpoint
2. A Network Load Balancer provides SSL termination and acts as a proxy for Karmada services running on Amazon EKS parent cluster
3. The Karmada Control Plane exposes the Karmada API via its API server in addition to the Kubernetes API. which receives calls for Kubernetes and Karmada management tasks
4. Karmada runs several components on the Amazon EKS compute nodes. To keep records of API objects and state, its API server uses own etcd database deployment.
5. Karmada etcd database uses EBS volumes  attached to compute Node EC2 instances to keep its state and consistency. All state changes and updates get persisted in EBS volumes across all EC2 compute nodes that host etcd pods.


**Karmada Application Deployment Architecture Steps:**

1. User interacts with the Karmada API server (part of Karmada Control Plane) using the kubectl CLI with Karmada plugin. User sends a command for multiple clusters, ex. a multi-region deployment of NGNIX application with  equal weight across two member EKS clusters
2. The Karmada Control Plane maintains the status and state of all member EKS clusters. Upon receiving the user request it interprets the requirement and instructs member clusters accordingly. E.G. run an NGINX deployment in each member cluster
3. The EKS cluster member 1 receives instructions from Karmada Control Plane to deploy and run an NGINX container application deployment
4. The EKS cluster member 1 receives instructions from Karmada Control Plane to deploy and run an NGINX container application deployment
5. The EKS Karmada Control Plane cluster checks application deployment status on the member clusters and updates state in its etcd database
6. User validates the status of multi-cluster application deployment communicating with Karmada Control Plane via kubectl Karmada CLI


### AWS services in this Guidance

Include links to AWS services, core, supporting, and optional that arecdeployed in this Guidance. In the AWS service column, add the official
name of the AWS service with a link to its main page. In the Description column, explain specifically how the AWS service is used in this
Guidance. Don't provide a generic description of the service. List the core AWS services first and start the description text with the
boilerplate Core. For supporting AWS services, start the description text with the boilerplate Supporting. For optional AWS services, start
the description text with the boilerplate Optional.

- [Amazon Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/){:target="_blank"}
- [Amazon Elastic Container Registry (ECR)](https://aws.amazon.com/ecr/){:target="_blank"}
- [Amazon Elastic Compute Cloud (EC2)](https://aws.amazon.com/ec2/){:target="_blank"}

## Plan your deployment

Include all deployment planning topics under this section, such as
costs,system requirements, deployment pre-requisites, service quotas,
Region considerations, and template dependencies.

### Cost 

This section is for a high-level cost estimate. Think of a likely
straightforward scenario with reasonable assumptions based on the
problem the Guidance is trying to solve. If applicable, provide an
in-depth cost breakdown table in this section.

Start this section with the following boilerplate text:

You are responsible for the cost of the AWS services used while running this Guidance. As of \<month\> \<year\>, the cost for running this
Guidance with the default settings in the \<Default AWS Region (Most likely will be US East (N. Virginia)) \> is approximately **\$\<n.nn\>
an hour**.

Refer to the pricing webpage for each AWS service used in this Guidance.

Replace this amount with the approximate cost for running your Guidance in the default Region. This estimate might be per hour, per minute, or
any other appropriate measure.

Suggest you keep this boilerplate text:

We recommend creating
a [budget](https://alpha-docs-aws.amazon.com/awsaccountbilling/latest/aboutv2/budgets-create.html){:target="_blank"} through [AWS
Cost
Explorer](http://aws.amazon.com/aws-cost-management/aws-cost-explorer/){:target="_blank"} to
help manage costs. Prices are subject to change. For full details, refer
to the pricing webpage for each AWS service used in this Guidance.

### Sample cost table

The following table provides a sample cost breakdown for deploying this
Guidance with the default parameters in the US East (N. Virginia) Region
for one month.

| **AWS service**  | Dimensions | Cost \[USD\] |
|-----------|------------|
| Amazon API Gateway | 1,000,000 REST API calls per month  | \$ 3.50month |
| Amazon Cognito | 1,000 active users per month without advanced security feature | \$ 0.00 |

## Security

Add the following boilerplate text to the beginning of this section:

When you build systems on AWS infrastructure, security responsibilities
are shared between you and AWS. This [shared responsibility
model](https://aws.amazon.com/compliance/shared-responsibility-model/){:target="_blank"}
reduces your operational burden because AWS operates, manages, and
controls the components including the host operating system, the
virtualization layer, and the physical security of the facilities in
which the services operate. For more information about AWS security,
visit [AWS Cloud Security](http://aws.amazon.com/security/){:target="_blank"}.

Add components that were used to improve security (e.g., IAM roles and
permissions, AWS Secrets Manager etc.,) Include Amazon CloudFront
section if your Guidance has a web console or app. Include VPC Security
Groups section if your Guidance includes security groups. List examples
used under each category, where applicable. If your Guidance is a
security Guidance, you may be able to delete this section.

## 

### \<Supported AWS Regions\>

If your Guidance uses AWS services that are not available in all AWS
Regions, add this section listing the supported Regions for this
Guidance.

This Guidance uses the \<AWSServiceName\> service, which is not
currently available in all AWS Regions. You must launch this solution in
an AWS Region where \<AWSServiceName\> is available. For the most
current availability of AWS services by Region, refer to the [AWS
Regional Services
List](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/){:target="_blank"}.

\<Full Guidance name\> is supported in the following AWS Regions:

Provide a list of all Regions where all services used in the Guidance
are supported. Provide name only and use two columns if list is 7 items
or longer.

Per the [AWS Style guide on
Regions](https://alpha.www.docs.aws.a2z.com/awsstyleguide/latest/styleguide/style-regions.html){:target="_blank"},
when listing Regions in documentation, US Regions must be listed first,
followed by all others. List US Regions in the order shown in the
following list, with all other Regions listed afterward in alphabetical
order.

In exception to this, [US East (Ohio) should always come first]{.mark},
followed by US East (N. Virginia). GovCloud Regions come last. Here's an
example:

| **Region Name**  | | 
|-----------|------------|
|US East (Ohio) | Asia Pacific ( Seoul ) |
|US East (N. Virginia) | Europe (Paris) |
|US West (Northern California) | Middle East (Bahrain) |
|US West (Oregon) | AWS GovCloud (US-West) |
|Africa (Cape Town)  | Asia Pacific ( Seoul ) |

### Quotas

Add this boilerplate text:

Service quotas, also referred to as limits, are the maximum number of
service resources or operations for your AWS account.

### Quotas for AWS services in this Guidance

Make sure you have sufficient quota for each of the services implemented
in this solution. For more information, see [AWS service
quotas](https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html){:target="_blank"}.

To view the service quotas for all AWS services in the documentation
without switching pages, view the information in the [Service endpoints
and
quotas](https://docs.aws.amazon.com/general/latest/gr/aws-general.pdf#aws-service-information){:target="_blank"}
page in the PDF instead.

## Deploy the Guidance 

### Prerequisites

List any prerequisites required before deploying the Guidance. For
examples, refer to [Dynamic Object and Rule Extensions for AWS Network
Firewall](https://docs.aws.amazon.com/solutions/latest/dynamic-object-and-rule-extensions-for-aws-network-firewall/deployment.html){:target="_blank"}
and [Scale-Out Computing on
AWS](https://docs.aws.amazon.com/solutions/latest/scale-out-computing-on-aws/deployment.html){:target="_blank"}.

### Deployment process overview

Before you launch the Guidance, review the cost, architecture, security,
and other considerations discussed in this guide. Follow the
step-by-step instructions in this section to configure and deploy the
Guidance into your account.

**Time to deploy:** Approximately tk minutes

### Write Procedures using a "Step-by-Step" Format

When writing procedures, find a natural break in a workflow and chunk it
into 7-10 steps, with each user decision as its own step. 

-   Title the section that includes the steps. The title reflects the
    objectives.

-   The steps should flow logically, from beginning to end.

-   Number lists that have more than one action.

-   Aim for \~15 words in a sentence with a max of 25 words.

-   Bold UI terms.

-   Avoid using capitalization or italics for emphasis. Let the language
    speak for itself.


**Sample Code**

When including sample code, provide the name of the programming language
at the top of the code. This helps when the tech writers format this
guide for GitHub.

***Example:***

Below is the policy JSON to associate with the IAM user:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Resource": [
                "arn:aws:s3:::<bucket-name>/*",
                "arn:aws:s3:::<bucket-name>"
            ]
        }
    ]
}
```
## Uninstall the Guidance

Edit the following content to ensure that the customer can completely
uninstall the Guidance if they choose to do so and not incur additional
costs.

You can uninstall the \<Guidance-name\> solution from the AWS Management
Console or by using the AWS Command Line Interface. You must manually
delete the \<list of Guidance resources such as Amazon Simple Storage
Service (Amazon S3) bucket\> created by this Guidance. AWS Guidance\'s
Implementations do not automatically delete \<this resource\> in case
you have stored data to retain.

### Related resources

Link to relevant resources and add a sentence describing how the linked
solution is related.

**Example:**

-   The \<related Guidance/solution link\> is similar to
    \<Guidance-name\>, but its default implementation is designed for
    enterprise customers instead of individual users.

Insert additional resources that can help the customer in a bulleted
list.

### Contributors

-   \<Author1 Firstname Lastname\>

-   \<Autho2 Firstname Lastname\>


## Notices

Customers are responsible for making their own independent assessment of the information in this document. This document: (a) is for
informational purposes only, (b) represents AWS current product offerings and practices, which are subject to change without notice, and
(c) does not create any commitments or assurances from AWS and its affiliates, suppliers or licensors. AWS products or services are
provided "as is" without warranties, representations, or conditions of any kind, whether express or implied. AWS responsibilities and
liabilities to its customers are controlled by AWS agreements, and this document is not part of, nor does it modify, any agreement between AWS
and its customers.
