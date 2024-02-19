#!/bin/bash -x
yum update -y
yum install -y git

# Adjust the following variables accordingly
VPC="karmada"
CLUSTERS_NAME="karmada"
REGION="us-east-1"

# Uncomment the following line If you have already deployed the parent cluster. Replicate and adjust accordingly if you have member clusters deployed
# su -c "aws eks update-kubeconfig --region ${REGION} --name ${CLUSTERS_NAME}-parent" ec2-user

cd /home/ec2-user


su -c "git clone https://github.com/aws-solutions-library-samples/guidance-for-multi-cluster-management-eks-karmada.git" ec2-user
cd guidance-for-multi-cluster-management-eks-karmada/eks-karmada-deploy

su -c "bash /home/ec2-user/guidance-for-multi-cluster-management-eks-karmada/eks-karmada-deploy/deploy-karmada-run.sh -r ${REGION} -v ${VPC} -c ${CLUSTERS_NAME} -k /home/ec2-user -u" ec2-user