# Multi cluster management with Amazon EKS and Karmada

This guidance show you how to deploy a federated Kubernetes environment in [Amazon Web Services](https://aws.amazon.com/) cloud using [Amazon Elastic Kubernetes Service (Amazon EKS)](https://aws.amazon.com/eks/) and the open source [Kubernetes Armada (Karmada)](https://karmada.io/) project. Karmada is a Kubernetes management system, with advanced scheduling capabilities, that enables you to run your cloud-native applications across multiple Kubernetes clusters and clouds, with no changes to your applications. This guide focuses on deploying Karmada on top of a highly available Amazon EKS cluster.

## Implementation Guide

The [implementation guide](IMPLEMENTATION_GUIDE) has the full details and a step by step guidance to:

- Prepare your environment
- Deploy Amazon EKS clusters for use with Karmada
- Deploy Karmada control plane in main Amazon EKS cluster (parent)
- Join Amazon EKS member cluster to Karmada for multi-cluster management
- Deploy a demo workload as a proof of concept for testing your Karmada deployment

## Automatic Deployment

For your convinience you can use the script [deploy_karmada.sh](eks-karmada-deploy/deploy_karmada.sh) for a fully automated process of the implementation guide. It will automate the Amazon EKS clusters deployment, Karmada deployment, join member EKS clusters to Karmada and deploy a demo workload across different clusters.

Refer to the [README](eks-karmada-deploy/README.md) file in the *eks-karmada-deploy* directory for usage instructions and further details.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
