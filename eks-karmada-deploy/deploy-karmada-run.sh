#!/bin/bash
# Author: Alexandros Soumplis (soumplis@amazon.com)
# Description: Self-service deployment script for Amazon EKS clusters and Karmada

# shellcheck disable=SC2015,2181

# Import the required functions
source ./include/deploy-karmada-functions.sh
trap cleanup EXIT

# Parse parameters
source ./include/deploy-karmada-usage.sh

# Check user wants to clean up the environment
[[ "${DELETE}" == "true" ]] && delete_deployment

[[ ${UNATTENDED} != "true" ]] && { echo -en "\nPress enter to continue or Ctrl-C to abort "; read -r; }

echo_green "${uni_right_triangle} Checking prerequisites\n"

# check the OS we ara running on
running_on

# if -z option is not present then proceed with check and install of utilities
[[ ${SKIP_UTILS} != "true" ]] && { os_package_manager; install_os_packages; install_kubectl; install_eksctl; install_awscli; }

echo_green "${uni_right_triangle} Prepare some parameters\n"
    # If not user-defined EKS version, retreive and use the latest available
    if [[ "${EKS_VERSION}" == "latest" ]]; then
        EKS_VERSION="$(aws eks describe-addon-versions --region "${REGION}" --output json | jq -r ".addons[] | .addonVersions[] | .compatibilities[] | .clusterVersion" | sort | uniq | tail -1)"
    fi

    VPCID="$(aws ec2 describe-vpcs --region "${REGION}" --filter "Name=tag:Name,Values=*${VPC_NAME}*" --query "Vpcs[].VpcId" --output text)"
    [[ -z "${VPCID}" ]] && { echo_red "\t${uni_x} VPC ${VPC_NAME} not found, exiting\n"; exit 5; }
    echo_orange "\t${uni_check} VPC ID: ${VPCID}\n"
    get_subnets
    echo_orange "\t${uni_check} Private Subnets: ${PRIVATE_SUBNETS}\n"
    echo_orange "\t${uni_check} Public Subnets: ${PUBLIC_SUBNETS}\n"
    ACCOUNTID="$(aws sts get-caller-identity --query "Account" --output text)"
    echo_orange "\t${uni_check} Account ID: ${ACCOUNTID}\n"

echo_green "${uni_right_triangle} Deploy cloudformation stack for usage recording\n"
    solution_usage_code

echo_green "${uni_right_triangle} Creating the Karmada parent cluster\n"
    eks_create_cluster "${CLUSTERS_NAME}-parent"

echo_green "${uni_right_triangle} Deploy the EBS addon for Karmada HA\n"
    eks_deploy_ebs "${CLUSTERS_NAME}-parent"

echo_green "${uni_right_triangle} Deploy Karmada Load Balancer\n"
    eks_lb_deploy "${CLUSTERS_NAME}-parent"
    echo_orange "\t${uni_check} Karmada Load Balancer DNS name: ${KARMADA_LB}\n"

echo_green "${uni_right_triangle} Deploy Karmada Control Plane\n"
    eks_karmada_deploy "${CLUSTERS_NAME}-parent"

if [[ ${MEMBER_CLUSTER_NUM} -ge 1 ]]; then
    echo_green "${uni_right_triangle} Creating the Karmada member clusters\n"
        for i in $(seq 1 "${MEMBER_CLUSTER_NUM}"); do
            eks_create_cluster "${CLUSTERS_NAME}-member-${i}"
        done

    # Check if we have at least 2 member clusters to deploy the demo
    if [[ ${MEMBER_CLUSTER_NUM} -ge 2 ]]; then
        for i in $(seq 1 "${MEMBER_CLUSTER_NUM}"); do
            echo_green "${uni_right_triangle} Registering the Karmada member cluster ${CLUSTERS_NAME}-member-${i} to Karmada\n"
                eks_karmada_register "${CLUSTERS_NAME}-member-${i}" "${CLUSTERS_NAME}-parent"
        done

        echo_green "${uni_right_triangle} Deploy demo workload with Karmada\n"
            eks_karmada_demo_deploy "${CLUSTERS_NAME}-member-1" "${CLUSTERS_NAME}-member-2" "${CLUSTERS_NAME}-parent"
    fi
fi

echo_green "${uni_right_triangle} Switching to the Karmada parent cluster context\n"
    eks_set_context "${CLUSTERS_NAME}-parent"

echo_green "${uni_right_triangle} Installation is complete\n"
    eks_karmada_summary

exit 0
