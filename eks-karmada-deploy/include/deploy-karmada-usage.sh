#!/bin/bash
# Author: Alexandros Soumplis (soumplis@amazon.com)
# Description: Usage function and default parameter set for Karmada deployment scripts

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
while getopts ":e:v:r:c:n:p:m:a:s:k:dhztuw" opt; do
  case $opt in
    e) EKS_VERSION="${OPTARG}";;
    v) VPC_NAME="${OPTARG}";;
    r) REGION="${OPTARG}";;
    c) CLUSTERS_NAME="$(echo ${OPTARG} | tr '[:upper:]' '[:lower:]')";;
    n) CLUSTER_NODES_NUM="${OPTARG}"; 
        [[ ${CLUSTER_NODES_NUM} -lt 3 ]] && { echo_red "This script deploys Karmada in high availability mode and you need at least 3 nodes for your cluster.\nPlease adjuct the parameter -n to 3 or more\n"; exit 1;} ;;
    p) CLUSTER_VCPUS="${OPTARG}";;
    m) CLUSTER_MEMORY="${OPTARG}";;
    a) CLUSTER_CPU_ARCH="${OPTARG}";;
    s) MEMBER_CLUSTER_NUM="${OPTARG}";;
    k) KARMADA_HOME="${OPTARG}/.karmada";;
    u) UNATTENDED="true";;
    z) SKIP_UTILS="true";;
    t) SKIP_USAGE="true";;
    w) MEMBER_CLUSTER_NUM=0;;
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
        echo "  -w No member clusters and demo    (deploy only parent EKS cluster and Karmada control plane )"
        echo ""
        echo "  -z Skip utilities installation    (ensure you have installed and configure the utilities: jq, awscli v2, eksctl, kubectl)"
        echo "  -t Skip usage recording           (do not record usage data)"
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