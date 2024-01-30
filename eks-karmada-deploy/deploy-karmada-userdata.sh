#!/bin/bash
# Author: Alexandros Soumplis (soumplis@amazon.com)
# Description: This script deploys Karmada on AWS EKS clusters from userdata during init

# shellcheck disable=SC2015,2181

# Import the required functions
source ./include/deploy-karmada-functions.sh
trap cleanup EXIT

# Parse parameters
source ./include/deploy-karmada-usage.sh

echo_green "${uni_right_triangle} Prepare some parameters\n"
    # Get the account id and the VPC id
    ACCOUNTID="$(aws sts get-caller-identity --query "Account" --output text)"
    VPCID="$(aws ec2 describe-vpcs --region "${REGION}" --filter "Name=tag:Name,Values=*${VPC_NAME}*" --query "Vpcs[].VpcId" --output text)"
    [[ -z "${VPCID}" ]] && { echo_red "\t${uni_x} VPC ${VPC_NAME} not found, exiting\n"; exit 5; }
    echo_orange "\t${uni_check} VPC ID: ${VPCID}\n"
    echo_orange "\t${uni_check} Account ID: ${ACCOUNTID}\n"

    # Get the public and private subnets of the the VPC
    get_subnets
    echo_orange "\t${uni_check} Private Subnets: ${PRIVATE_SUBNETS}\n"
    echo_orange "\t${uni_check} Public Subnets: ${PUBLIC_SUBNETS}\n"

# Deploy the EBS addon to the parent Karmada cluster
echo_green "${uni_right_triangle} Deploy the EBS addon for Karmada HA\n"
    eks_deploy_ebs "${CLUSTERS_NAME}-parent"

# Deploy a network load balancer for the Karmada API server
echo_green "${uni_right_triangle} Deploy Karmada Load Balancer\n"
    eks_lb_deploy "${CLUSTERS_NAME}-parent"
    echo_orange "\t${uni_check} Karmada Load Balancer DNS name: ${KARMADA_LB}\n"

echo_green "${uni_right_triangle} Deploy Karmada Control Plane\n"
    eks_karmada_deploy "${CLUSTERS_NAME}-parent"

echo_green "${uni_right_triangle} Registering Karmada member clusters\n"
    for i in $(seq 1 "${MEMBER_CLUSTER_NUM}"); do
        echo_green "${uni_right_triangle} Registering the Karmada member cluster ${CLUSTERS_NAME}-member-${i} to Karmada\n"
            eks_karmada_register "${CLUSTERS_NAME}-member-${i}" "${CLUSTERS_NAME}-parent"
    done

if [[ ${MEMBER_CLUSTER_NUM} -ge 2 ]]; then
    echo_green "${uni_right_triangle} Deploy demo workload with Karmada\n"        
        eks_karmada_demo_deploy "${CLUSTERS_NAME}-member-1" "${CLUSTERS_NAME}-member-2" "${CLUSTERS_NAME}-parent"
fi

echo_green "${uni_right_triangle} Switching to the Karmada parent cluster context\n"
    eks_set_context parent
