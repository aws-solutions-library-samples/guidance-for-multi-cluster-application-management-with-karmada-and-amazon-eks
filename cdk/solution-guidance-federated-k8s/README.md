Multi-cluster application management with EKS and Karmada on AWS fully automated deployment with the AWS CDK. This package uses CDK in Java and you can use it to perform an end-to-end deployment of an EKS parent cluster and the Karmada control plane that allows you to join and manage any other Amazon EKS or other Kubernetes cluster. 

## Getting started

To work with the AWS CDK, you must have an AWS account and credentials and have installed Node.js and the AWS CDK Toolkit. As per the instructions in [AWS CDK Prerequisites](https://docs.aws.amazon.com/cdk/v2/guide/work-with.html#work-with-prerequisites) to manage CDK packages in Java you have to use [Apache Maven 3.5](https://maven.apache.org/) or later. . Java AWS CDK applications require Java 8 (v1.8) or later. We recommend [Amazon Corretto](https://aws.amazon.com/corretto/), but you can use any OpenJDK distribution or [Oracle's JDK](https://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html). For more information on using the CDK in Java, please see the [Developer Guide](https://docs.aws.amazon.com/cdk/latest/guide/work-with-cdk-java.html).

## Prerequisites

To use this solutions deployment with the AWS CDK you need to have in place the following prerequisites:

- An active [AWS Account](https://docs.aws.amazon.com/accounts/latest/reference/welcome-first-time-user.html){:target="_blank"} to deploy the main Amazon EKS cluster
- A [user with administrator access](https://docs.aws.amazon.com/streams/latest/dev/setting-up.html){:target="_blank"} and an [Access key/Secret access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html){:target="_blank"} to configure [AWS Command Line Interface(AWS CLI)](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html){:target="_blank"} 

## Deployment

### Deploy with AWS CloudShell

Unless you already have your development environment setup you can use [AWS CloudShell](https://aws.amazon.com/cloudshell/) to quickly deploy the solution. CloudShell is available from the AWS Management Console by clicking the shell icon in the top navigation bar. This will open a CloudShell environment in the current region with access to AWS Services. 

**WARNING** CloudShell is designed for focused, task-based activities. It is **not** meant for tasks that need to keep state and persistent data (ex. installation of system packages). Also, your shell session automatically ends after approximately 20–30 minutes if you don't interact with AWS CloudShell using your keyboard or pointer. Running processes don't count as interactions, so while running this script make sure that you interact with the shell (ex. press Enter key) every 15 minutes to avoid timeouts and interrupting the script run. and its use in this solutions is only recommended as a means for quick testing and you should **never** rely on it for production use.

The use of AWS CloudShell for this solutions is only recommended as a means for quick testing. If you want to perform a production grade deployment using an AWS service with more flexible timeouts and data persistency, we recommend using our cloud-based IDE, [AWS Cloud9](https://docs.aws.amazon.com/cloud9), or launching and [connecting to an Amazon EC2 instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstances.html).

Assuming you are logged in to the AWS Management Console using a user with adequate permissions, open a CloudShell follow the "Deployment commands" below.

### Deploy with AWS Cloud9

Another option to have a stable and stateful deployment with minimum administration overhead and reduced cost, is to use [AWS Cloud9](https://aws.amazon.com/cloud9/). Follow the official documentation for [Creating an EC2 Environment](https://docs.aws.amazon.com/cloud9/latest/user-guide/create-environment-main.html) to create a new Cloud9 environment in the same VPC as the one you are going to use for Karmada deployment. Due to the nature of the deployment you cannot use AWS Cloud9 temporary credentials, but instead you have two options. Either [Create and use an instance profile to manage temporary credentials](https://docs.aws.amazon.com/cloud9/latest/user-guide/credentials.html#credentials-temporary) or [Create and store permanent access credentials in an Environment](https://docs.aws.amazon.com/cloud9/latest/user-guide/credentials.html#credentials-permanent-create).

As long as you setup the credentials start a new terminal session (on the menu bar, choose Window, New Terminal) and follow the "Deployment commands" below.

### Deployment commands

1. Install Node.js 

First you need to install Node.js in the CloudShell instance. You can do this with the following command.

**WARNING** AWS does not control the following code. Before you run it, be sure to verify its authenticity and integrity. More information about this code can be found in the [nvm](https://github.com/nvm-sh/nvm/blob/master/README.md) GitHub repository.

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```

2. Install AWS CDK

Next, install the aws-cdk package using Node.js package manager

```bash
sudo npm install -g aws-cdk
```

3. Install Amazon Corretto

Install the latest version of [Amazon Corretto](https://docs.aws.amazon.com/corretto/latest/corretto-21-ug/amazon-linux-install.html) for Amazon Linux.

```bash
sudo yum install -y java-21-amazon-corretto-headless
```

4. Install Apache Maven

Download the latest version of [Apache Maven](https://maven.apache.org/download.cgi), extract it and temporarily change the path to include the Apache Maven bin directory

```bash
curl -sLO https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz
tar xzf apache-maven-3.9.6-bin.tar.gz
echo "export PATH=$PATH:~/apache-maven-3.9.6/bin" >> ~/.bashrc
source ~/.bashrc
command -v mvn
```

5. Prepare for the deployment

Download the [code](https://github.com/aws-solutions-library-samples/guidance-for-multi-cluster-management-eks-karmada) from Github and then get into the CDK code directory and run the preparation step. If it is your first run you **need** to run the `cdk bootstrap` command. 

```bash
git clone https://github.com/aws-solutions-library-samples/guidance-for-multi-cluster-management-eks-karmada.git
cd guidance-for-multi-cluster-management-eks-karmada/cdk/solution-guidance-federated-k8s/
mvn clean package
cdk bootstrap
cdk synth
```

5. Deploy the solution

Now you are ready to deploy the solution with all the components described in the section below. 

```bash
cdk deploy
```

## What this CDK deploys

This solution will deploy the following resources:
- An Amazon VPC with the name karmada-vpc
- Into this VPC, 3 private and 3 public subnets
- An Internet and a NAT gateway for Internet access for all hosts
- One Amazon EKS cluster with a node group with 3 worker nodes.
- One EC2 instance to use as the management host for the EKS cluster and Karmada control plane. The following utils deployed and installed in the management host: awscli v2, kubectl, karmada plugin.
- Karmada control plane deployed in the EKS cluster and the Karmada API configuration files and certificates in the management host, under /home/ec2-user/.karmada
- One Network Load Balancer to handle communication to the Karmada API service

## Uninstall

To uninstall the solutions and remove all relevant resources, get to the terminal that you have the CDK code and you used to deploy and run the command

```bash
cdk destroy
```

## Useful commands

 * `mvn package`     compile and run tests
 * `cdk ls`          list all stacks in the app
 * `cdk synth`       emits the synthesized CloudFormation template
 * `cdk deploy`      deploy this stack to your default AWS account/region
 * `cdk diff`        compare deployed stack with current state
 * `cdk docs`        open CDK documentation

## Useful kubectl commands

 * `aws eks update-kubeconfig --name <cluster-name> --role-arn <master-role>`   get access to the cluster
 * `kubectl get svc -A`                                                         get all services
 * `kubectl get pods -A`                                                        get the pods deployed on our cluster
 * `kubectl get sc -A`                                                          get storage classes
 * `kubectl describe sc ebs-sc`                                                 get details for the ebs-sc storage class
 * `kubectl get nodes -A -o wide`                                               get information for the nodes of the cluster