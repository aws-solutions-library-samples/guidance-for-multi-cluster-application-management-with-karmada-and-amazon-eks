#!/bin/bash
# Author: Alexandros Soumplis (soumplis@amazon.com)
# Description: Self-service deployment script for Amazon EKS clusters and Karmada

# shellcheck disable=SC2015,2181

# Import the required functions
source ./include/deploy-karmada-functions.sh

# Parse parameters
source ./include/deploy-karmada-usage.sh

trap cleanup EXIT

# Check user wants to clean up the environment
if [[ "${DELETE}" == "true" ]]; then
    delete_deployment
fi

if [[ ${UNATTENDED} != "true" ]]; then
    # show the values of the parameters
    echo "Ready to run the Karmada deployment script with the following parameters:"
    echo -n "  Amazon EKS version: "; echo_orange "${EKS_VERSION}\n"
    echo -n "  VPC name: "; echo_orange "${VPC_NAME}\n"
    echo -n "  Region: "; echo_orange "${REGION}\n"
    echo -n "  Cluster name prefix: "; echo_orange "${CLUSTERS_NAME}\n"
    echo -n "  Cluster nodes: "; echo_orange "${CLUSTER_NODES_NUM}\n"
    echo -n "  Cluster nodes CPUs: "; echo_orange "${CLUSTER_VCPUS}\n"
    echo -n "  Cluster nodes memory: "; echo_orange "${CLUSTER_MEMORY}\n"
    echo -n "  Cluster CPU arch: "; echo_orange "${CLUSTER_CPU_ARCH}\n"
    echo -n "  Number of karmada member clusters: "; echo_orange "${MEMBER_CLUSTER_NUM}\n"
    echo -n "  Karmada HOME dir: "; echo_orange "${KARMADA_HOME}\n\n"
    echo "Please note that depending on the number of clusters you are deploying,"
    echo "this script may take a while to complete (expect 20+ minutes per cluster)."
    echo -en "\nPress enter to continue or Ctrl-C to abort "
    read -r
fi

echo_green "${uni_right_triangle} Checking prerequisites\n"

# check the OS
running_on

# if -z option is not present then proceed with check and install of utilities
if [[ ${SKIP_UTILS} != "true" ]]; then
    # check the OS package manager
    os_package_manager
    install_os_packages
    install_kubectl
    install_eksctl
    install_awscli
fi

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

echo_green "${uni_right_triangle} Creating the Karmada member clusters\n"
for i in $(seq 1 "${MEMBER_CLUSTER_NUM}"); do
    eks_create_cluster "${CLUSTERS_NAME}-member-${i}"
done

echo_green "${uni_right_triangle} Deploy Karmada Load Balancer\n"
eks_lb_deploy "${CLUSTERS_NAME}-parent"
echo_orange "\t${uni_check} Karmada Load Balancer DNS name: ${KARMADA_LB}\n"
echo_green "${uni_right_triangle} Deploy Karmada Control Plane\n"
eks_karmada_deploy "${CLUSTERS_NAME}-parent"

for i in $(seq 1 "${MEMBER_CLUSTER_NUM}"); do
    echo_green "${uni_right_triangle} Registering the Karmada member cluster ${CLUSTERS_NAME}-member-${i} to Karmada\n"
    eks_karmada_register "${CLUSTERS_NAME}-member-${i}" "${CLUSTERS_NAME}-parent"
done

[[ ${MEMBER_CLUSTER_NUM} -ge 2 ]] && eks_karmada_demo_deploy "${CLUSTERS_NAME}-member-1" "${CLUSTERS_NAME}-member-2" "${CLUSTERS_NAME}-parent"
echo_green "${uni_right_triangle} Switching to the Karmada parent cluster context\n"
eks_set_context "${CLUSTERS_NAME}-parent"

echo_green "${uni_right_triangle} Installation is complete\n"
eks_karmada_summary

exit 0
