#!/bin/bash
# Author: Alexandros Soumplis (soumplis@amazon.com)
# Description: Self-service deployment script for Amazon EKS clusters and Karmada

# shellcheck disable=SC2015,2181

# Import the required functions

source ./include/deploy-karmada-functions.sh


# Define default values for required parameters. These can be overriden with command line parameters
EKS_VERSION="latest"
VPC_NAME="vpc-eks"
REGION="eu-north-1"
CLUSTERS_NAME="karmada"
CLUSTER_NODES_NUM=3 # You need at least three worker nodes for Karmada HA api server
CLUSTER_VCPUS=2
CLUSTER_MEMORY=4
CLUSTER_CPU_ARCH="x86_64"
MEMBER_CLUSTER_NUM=2
KARMADA_HOME="${HOME}/.karmada"
CLUSTER_NAMES="" # to be used only for cleanup operations

# Let's parse any command line parameters
while getopts ":e:v:r:c:n:p:m:a:s:k:dhzu" opt; do
  case $opt in
    e) EKS_VERSION="${OPTARG}";;
    v) VPC_NAME="${OPTARG}";;
    r) REGION="${OPTARG}";;
    c) CLUSTERS_NAME="${OPTARG}";;
    n) CLUSTER_NODES_NUM="${OPTARG}"; 
        [[ ${CLUSTER_NODES_NUM} -lt 3 ]] && { echo_red "This script deploys Karmada in high availability mode and you need at least 3 nodes for your cluster.\nPlease adjuct the parameter -n to 3 or more\n"; exit 1;} ;;
    p) CLUSTER_VCPUS="${OPTARG}";;
    m) CLUSTER_MEMORY="${OPTARG}";;
    a) CLUSTER_CPU_ARCH="${OPTARG}";;
    s) MEMBER_CLUSTER_NUM="${OPTARG}";;
    k) KARMADA_HOME="${OPTARG}/.karmada";;
    u) UNATTENDED="true";;
    z) SKIP_UTILS="true";;
    d) DELETE="true";;
    h) 
        echo "Usage: $0 [args]"
        echo ""
        echo "Arguments:"
        echo "  -e EKS version                    (default: 1.28)"
        echo "  -v VPC name                       (default: vpc-manual)"
        echo "  -r Region                         (default: eu-north-1)"
        echo "  -c Cluster name                   (default: karmada)"
        echo "  -n Number of cluster nodes        (default: 3) - You need at least 3 nodes for Karmada high availability"
        echo "  -p Cluster VCPUs                  (default: 2)"
        echo "  -m Cluster memory                 (default: 4)"
        echo "  -a Cluster CPU architecture       (default: x86_64)"
        echo "  -s Number of member cluster       (default: 2)"
        echo "  -k Karmada home directory         (default: ~ --- this results in your karmada config to be in ~/.karmada directory)"
        echo "  -u Unattended installation        (do not ask for confirmation, to allow unattended deployment)"
        echo ""
        echo "  -z Skip utilities installation    (ensure you have installed and configure the utilities: jq, awscli v2, eksctl, kubectl)"
        echo ""
        echo "  -d clean up the deployment        (delete EKS clusters with the prefix, cleanup karmada home dir)"
        echo ""
        echo "  -h  Display this help message"
        exit 0;;
    :) echo "Option -${OPTARG} requires an argument. Use -h for more information"; exit 1;;
    \?) echo "Invalid option: -${OPTARG}. Use -h for more information"; exit 1;;
    *) echo "Invalid option: -${OPTARG}. Use -h for more information"; exit 1;;
  esac
done

trap cleanup EXIT

# Check user wants to clean up the environment
if [[ "${DELETE}" == "true" ]]; then
    # get all clusters with name having prefix CLUSTERS_NAME
    CLUSTER_NAMES=$(aws eks list-clusters --region "${REGION}" --output json | jq -r '.clusters[]' | grep "^${CLUSTERS_NAME}-" | xargs)
    if [[ -z "${CLUSTER_NAMES}" ]]; then
        echo_red "No EKS clusters found with the prefix ${CLUSTERS_NAME}\n"
        echo_red "Exiting...\n"
        exit 1
    fi

    echo_orange "This run will delete the following resources:\n"
    echo_orange "  - EKS clusters: ${CLUSTER_NAMES}\n"
    echo_orange "  - Karmada home directory ${KARMADA_HOME}\n"
    echo ""
    echo -n "To confirm type \"iReallyMeanIt\": "
    read -r confirm
    if [[ "${confirm}" == "iReallyMeanIt" ]]; then
        eks_karmada_delete
    else
        echo_red "You don't really mean it. Exiting...\n"
        exit 1
    fi
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

echo_green "${uni_right_triangle} Creating the Karmada parent cluster\n"
eks_create_cluster parent
echo_green "${uni_right_triangle} Deploy the EBS addon for Karmada HA\n"
eks_deploy_ebs parent

echo_green "${uni_right_triangle} Creating the Karmada member clusters\n"
for i in $(seq 1 "${MEMBER_CLUSTER_NUM}"); do
    eks_create_cluster "member-${i}"
done

echo_green "${uni_right_triangle} Deploy Karmada Load Balancer\n"
eks_lb_deploy parent
echo_orange "\t${uni_check} Karmada Load Balancer DNS name: ${KARMADA_LB}\n"
echo_green "${uni_right_triangle} Deploy Karmada Control Plane\n"
eks_karmada_deploy parent

for i in $(seq 1 "${MEMBER_CLUSTER_NUM}"); do
    echo_green "${uni_right_triangle} Registering the Karmada member cluster ${CLUSTERS_NAME}-member-${i} to Karmada\n"
    eks_karmada_register "member-${i}"
done

[[ ${MEMBER_CLUSTER_NUM} -ge 2 ]] && eks_karmada_demo_deploy member-1 member-2
echo_green "${uni_right_triangle} Switching to the Karmada parent cluster context\n"
eks_set_context parent

echo_green "${uni_right_triangle} Deploy cloudformation stack for usage recording\n"
solution_usage_code

echo_green "${uni_right_triangle} Installation is complete\n"
eks_karmada_summary

exit 0
