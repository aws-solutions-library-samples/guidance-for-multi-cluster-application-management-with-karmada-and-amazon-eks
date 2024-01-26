#!/bin/bash
# Author: Alexandros Soumplis (soumplis@amazon.com)
# Description: This script deploys Karmada on AWS EKS clusters

# We need nice colors for terminals that support it
function echo_red () { echo -ne "\033[0;31m${1}\033[0m"; }
function echo_orange () { echo -ne "\033[0;33m${1}\033[0m"; }
function echo_green () { echo -ne "\033[0;32m${1}\033[0m"; }

# We also like nice unicode characters
uni_right_triangle="\u25B7"
uni_circle_quarter="\u25D4"
uni_check="\u2714"
uni_x="\u2718"

# Let's parse any command line parameters
while getopts ":v:r:c:s:kh" opt; do
  case $opt in
    v) VPC_NAME="${OPTARG}";;
    r) REGION="${OPTARG}";;
    c) CLUSTERS_NAME="${OPTARG}";;
    s) MEMBER_CLUSTER_NUM="${OPTARG}";;
    k) KARMADA_HOME="${OPTARG}/.karmada";;
    h) 
        echo "Usage: $0 [args]"
        echo ""
        echo "Arguments:"
        echo "  -v VPC name"
        echo "  -r Region"
        echo "  -c Cluster name"
        echo "  -s Number of member clusters"
        echo "  -k Karmada home directory"
        echo ""
        echo "  -h  Display this help message"
        exit 0;;
    :) echo "Option -${OPTARG} requires an argument. Use -h for more information"; exit 1;;
    \?) echo "Invalid option: -${OPTARG}. Use -h for more information"; exit 1;;
    *) echo "Invalid option: -${OPTARG}. Use -h for more information"; exit 1;;
  esac
done

# Check we have all the required arguments

if [ -z ${VPC_NAME} ]; then
    echo_red "\t${uni_x} Parameter for VPC name (-v) cannot be empty\n"
elif [ -z ${REGION} ]; then
    echo_red "\t${uni_x} Parameter for region (-r) cannot be empty\n"
elif [ -z ${CLUSTERS_NAME} ]; then
    echo_red "\t${uni_x} Parameter for clusters' name (-c) cannot be empty\n"
elif [ -z ${MEMBER_CLUSTER_NUM} ]; then
    echo_red "\t${uni_x} Parameter for member clusters number (-s) cannot be empty\n"
elif [ -z ${KARMADA_HOME} ]; then
    echo_red "\t${uni_x} Parameter for Karmada config directory (-k) cannot be empty\n"
fi

# Function to resolve the IP address. Need it after deployment of load balancer as the Kubernetes API
# and the Karmada API server do not support (yet!) hostnames 
function resolve_ip () {    
    if [ "${RUNNINGON}" == "Mac" ]; then
        ping -c 1 ${1} | grep "^PING" | cut -f2 -d\( | cut -f1 -d\)        
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        ping -4 -c 1 ${1} | grep "^PING" | cut -f2 -d\( | cut -f1 -d\)
    elif [ "${RUNNINGON}" == "Cygwin" ]; then
        ping -4 -n 1 ${1} | grep "^Pinging" | cut -f2 -d\[ | cut -f1 -d\]
    fi
}

# Function to get all subnets from the vpc. The function classifies the subnets into public and private
# depending on the default route if it is with an IGW or a NATGW
function get_subnets () {
    # Initialize two local array variables to store the subnet IDs
    local publicsubnets=() 
    local privatesubnets=()

    # Initialize some local variables to use temporarily within the function
    local subnets
    local associated_subnets
    local igw
    local igw_routes
    local main_route
    
    # Get all subnets in the VPC
    subnets=$(aws ec2 describe-subnets --region "${REGION}" --filters "Name=vpc-id,Values=${VPCID}" --query 'Subnets[].SubnetId' --output text)
    # Get all subnets with explicit associations in route tables
    associated_subnets=$(aws ec2 describe-route-tables --region "${REGION}" --filters "Name=vpc-id,Values=${VPCID}" --query 'RouteTables[].Associations[].SubnetId' --output text)
    
    # Get internet gateways in the VPC
    igw=$(aws ec2 describe-internet-gateways --region "${REGION}" --filters "Name=attachment.vpc-id,Values=${VPCID}" --query 'InternetGateways[].InternetGatewayId' --output text)
    # Get route tables in the VPC with an igw attached
    igw_routes=$(aws ec2 describe-route-tables --region "${REGION}" --filters "Name=vpc-id,Values=${VPCID}" --query "RouteTables[?Routes[?GatewayId==\`${igw}\`]].RouteTableId" --output text)
    # Get the main route table for the explicit rules
    main_route=$(aws ec2 describe-route-tables --region "${REGION}" --filters "Name=vpc-id,Values=${VPCID}" --query "RouteTables[?Associations[?Main==\`true\`]].RouteTableId" --output text)

    # Loop through subnets
    for subnet in ${subnets}; do
        # Check if the subnet has an explicit association with a route table
        if [[ "${associated_subnets}" =~ ${subnet} ]]; then
            # the subnet has an explicit association, check if it is associated with a public route table
            [[ "${igw_routes}" =~ $(aws ec2 describe-route-tables --region "${REGION}" --filters "Name=association.subnet-id,Values=${subnet}" --query 'RouteTables[].RouteTableId' --output text) ]] && publicsubnets+=("${subnet}") || privatesubnets+=("${subnet}") 
        else
            # the subnet has no explicit association, it is implicitly associated with the main route table
            # if the main route table has an igw attached then the subnet is public, else it's private
            grep -qw "${main_route}" <<< "${igw_routes}" && publicsubnets+=("${subnet}") || privatesubnets+=("${subnet}")
        fi
    done

    # check that we have private and public subnets available and build lists in csv format
    [[ ${#privatesubnets[@]} -le 0 ]] && { echo_red "\t${uni_x} No private subnets found, exiting\n"; exit 5; } || PRIVATE_SUBNETS=$(echo "${privatesubnets[@]}" | tr ' ' ',')
    [[ ${#publicsubnets[@]} -le 0 ]] && { echo_red "\t${uni_x} No public subnets found, exiting\n"; exit 5; }  || PUBLIC_SUBNETS=$(echo "${publicsubnets[@]}" | tr ' ' ',')

    # check that public subnets have map ip on launch
    for subnet in "${publicsubnets[@]}"; do
        aws ec2 describe-subnets --region "${REGION}" --filters "Name=subnet-id,Values=${subnet}" --query 'Subnets[].MapPublicIpOnLaunch' --output text | grep -iqw "true"
        [[ $? -eq 0 ]] || { echo_red "\t${uni_x} Public subnet ${subnet} does not have map ip on launch, exiting\n"; exit 5; }
    done
}

function eks_set_context () {
    # function that sets the right context
    local desirable_context
    # Get the desirable context from the config file and use it
    echo_orange "\t${uni_circle_quarter} switching to the right context"
    desirable_context=$(kubectl config view -o json | jq -r '.contexts[]?.name' | grep "${CLUSTERS_NAME}-${1}")
    kubectl config use-context "${desirable_context}" > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_orange " ${uni_x}\n"; exit 5; }
}

# Function to deploy the EBS addon to an EKS custer
function eks_deploy_ebs () {
    # function that deploys the ebs addon and configures a new gp3 storage class
    # Ensure we are working in the right context
    eks_set_context "${1}"

    # Associate the IAM OIDC provider
    echo_orange "\t${uni_circle_quarter} associate the IAM OIDC provider"
    eksctl utils associate-iam-oidc-provider \
        -v 0 --region "${REGION}" --cluster "${CLUSTERS_NAME}-${1}" --approve > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_orange " ${uni_x}\n"; exit 5; }

    # Create the IAM service account with a region specific name
    echo_orange "\t${uni_circle_quarter} create IAM service account"
    eksctl create iamserviceaccount \
        -v 0 --region "${REGION}" --cluster "${CLUSTERS_NAME}-${1}" \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --name "ebs-csi-controller-sa" --namespace kube-system --approve --role-only \
        --role-name "AmazonEKS_EBS_CSI_DriverRole_${REGION}"  > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }

    # Deploy the EBS CSI driver with a region specific name
    echo_orange "\t${uni_circle_quarter} deploy EBS addon"
    eksctl create addon \
        -v 0 --region "${REGION}" --name aws-ebs-csi-driver --cluster "${CLUSTERS_NAME}-${1}" \
        --service-account-role-arn "arn:aws:iam::${ACCOUNTID}:role/AmazonEKS_EBS_CSI_DriverRole_${REGION}" --force  > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }

    # Create the gp3 storage class
    echo_orange "\t${uni_circle_quarter} create gp3 ebs storage class"
    {   echo '{ "apiVersion": "storage.k8s.io/v1",'
        echo '  "kind": "StorageClass",'
        echo '  "metadata": { "name": "ebs-sc" },'
        echo '  "provisioner": "ebs.csi.aws.com",'
        echo '  "volumeBindingMode": "WaitForFirstConsumer",'
        echo '  "parameters": { "type": "gp3" }'
        echo '}'
     } > /tmp/$$.ebs-sc.json

    kubectl apply -f /tmp/$$.ebs-sc.json > /dev/null
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; rm -f /tmp/$$.ebs-sc.json; } || { echo_red " ${uni_x}\n"; rm -f /tmp/$$.ebs-sc.json; exit 5; }
}

# Function to create the namespace for Karmada before deployment of Karmada
# so that we can deploy the load balancer under the right namespace
function eks_karmada_ns () {
    # function that checks (and creates if not exists) the karmada-system namespace
    # Ensure we are working in the right context
    eks_set_context "${1}"

    # Check if the namespace exists
    echo_orange "\t${uni_circle_quarter} check if namespace karmada-system exists"
    kubectl get namespace --no-headers | grep karmada-system > /dev/null 2>&1
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; KARMADA_LB=$(kubectl get svc -n karmada-system karmada-service-loadbalancer -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}'); return 0; } || { echo_red " ${uni_x}\n"; }

    # If the namespace does not exist, create it
    echo_orange "\t${uni_circle_quarter} create Karmada namespace"
    kubectl create namespace karmada-system > /dev/null
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; } || { echo_red " ${uni_x}\n"; }
}

# Function to deploy the load balancer for the Karmada API server
function eks_lb_deploy () {
    # function that deploys a network load balancer in the karmada-system namespace
    # Ensure we are working in the right context
    eks_set_context "${1}"

    # Ensure we have the karmada-system namespace in place
    eks_karmada_ns "${1}"

    # Check if the load balancer already exists
    echo_orange "\t${uni_circle_quarter} check if karmada network load balancer exists"
    kubectl get svc -n karmada-system karmada-service-loadbalancer --no-headers > /dev/null 2>&1
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; return 0; } || { echo_red " ${uni_x}\n"; }

    # Define the load balancer config and deploy
    echo_orange "\t${uni_circle_quarter} deploy karmada network load balancer"
    {   echo '{ "apiVersion": "v1",'
        echo '  "kind": "Service",'
        echo '  "metadata": { "name": "karmada-service-loadbalancer", "namespace": "karmada-system",'
        echo '                "annotations": {'
        echo '                  "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",'
        echo '                  "service.beta.kubernetes.io/aws-load-balancer-name": "karmada-lb",'
        echo '                  "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing",'
        echo '                  "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type": "ip" }'
        echo '},'
        echo '"spec": { "type": "LoadBalancer",'
        echo '          "selector": { "app": "karmada-apiserver" },'
        echo '          "ports": [{ "protocol": "TCP", "port": 32443, "targetPort": 5443 }] }'
        echo '}' 
    } > /tmp/$$.karmada-lb.json

    kubectl apply -f /tmp/$$.karmada-lb.json > /dev/null
    [[ $? -eq 0 ]] && { sleep 30; echo_green " ${uni_check}\n"; rm -f /tmp/$$.karmada-lb.json; } || { echo_red " ${uni_x}\n"; rm -f /tmp/$$.karmada-lb.json; exit 5; }
    
    # Wait for the load balancer to be available
    echo_orange "\t${uni_circle_quarter} Waiting for the load balancer to become ready"  
    LB_ARN=$(aws elbv2 describe-load-balancers --region "${REGION}" | jq -r '.LoadBalancers[].LoadBalancerArn' | xargs -I {} aws elbv2 describe-tags --region "${REGION}" --resource-arns {} --query "TagDescriptions[?Tags[?Key=='kubernetes.io/service-name'&&Value=='karmada-system/karmada-service-loadbalancer']].ResourceArn" --output text)
    LB_STATUS=$(aws elbv2 describe-load-balancers --region "${REGION}" --load-balancer-arns "${LB_ARN}" --query 'LoadBalancers[].State.Code' --output text)
    # Keep checking until load balancer status is active
    while [ "$LB_STATUS" != "active" ]
    do
        echo_orange "."
        sleep 10
        LB_STATUS=$(aws elbv2 describe-load-balancers --region "${REGION}" --load-balancer-arns "${LB_ARN}" --query 'LoadBalancers[].State.Code' --output text)
        [[ "$LB_STATUS" == "active" ]] && echo_green " ${uni_check}\n"
    done

    # Define the KARMADA_LB variable
    KARMADA_LB=$(kubectl get svc -n karmada-system karmada-service-loadbalancer -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}')
}

# Function to install the karmada plugin
function eks_karmada_plugin_install () {
    # function that installs the karmada plugin for kubectl
    # Check if the plugin is already installed
    command -v kubectl-karmada > /dev/null && { echo_orange "\t${uni_check} kubectl-karmada already installed\n"; return 0; }
    
    # If it is not installed, proceed with the installation
    echo_orange "\n\t${uni_circle_quarter} kubectl-karmada could not be found, installing it now"
    cd /tmp || { echo_red " ${uni_x}Cannot access /tmp directory\n"; exit 5; }
    curl -sL "https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh" | sudo bash -s kubectl-karmada
   
    # Check the plugin is deployed successfully
    command -v kubectl-karmada > /dev/null && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

# Function to deploy Karmada
function eks_karmada_deploy () {
    # function that deploys the karmada cluster
    local karmada_lb_ip
    # Ensure we are working in the right context
    eks_set_context "${1}"
    # Ensure we have the karmada plugin installed
    eks_karmada_plugin_install

    # Check if karmada is already initialised
    echo_orange "\t${uni_circle_quarter} check if karmada is already initialised"
    [[ $(kubectl get deployments -n karmada-system -o name | wc -l) -ge 1 ]] && { echo_green " ${uni_check}\n"; return 0; } || { echo_red " ${uni_x}\n"; }

    # Deploy the Karmada cluster
    # we use the public IP address of the first network load balancer instance as the kube api does not support multiple IP addresses
    # This is required for the init phase and internal karmada sync operations. All user-facing operation go through the load balancer DNS name
    echo_orange "\t${uni_circle_quarter} deploy Karmada api server\n"

    karmada_lb_ip=$(resolve_ip "${KARMADA_LB}")
    [[ -z ${karmada_lb_ip} ]] && { echo_red " ${uni_x} Could not determine the load balancer IP address\n"; exit 5; }
    kubectl karmada init \
     --karmada-apiserver-advertise-address "${karmada_lb_ip}" \
     --karmada-apiserver-replicas 3 --etcd-replicas 3 \
     --etcd-storage-mode PVC --storage-classes-name ebs-sc \
     --cert-external-dns="*.elb.${REGION}.amazonaws.com" \
     --karmada-data "${KARMADA_HOME}" --karmada-pki="${KARMADA_HOME}/pki"
    
    [[ $? -eq 0 ]] && { echo_orange "\t${uni_circle_quarter} deploy Karmada api server"; echo_green " ${uni_check}\n"; } || { echo_orange "\t${uni_circle_quarter} deploy Karmada api server"; echo_red " ${uni_x}\n"; exit 5; }
}

# Function to register an EKS cluster to Karmada
function eks_karmada_register () {
    # function that register an eks cluster to karmada
    # Ensure we have the karmada plugin installed
    eks_karmada_plugin_install

    # Check if the cluster is already registered
    eks_set_context parent
    echo_orange "\t${uni_circle_quarter} check if ${CLUSTERS_NAME}-${1} is already registered to Karmada cluster"
    [[ $(kubectl --kubeconfig "${KARMADA_HOME}/karmada-apiserver.config" get clusters | grep -c "${CLUSTERS_NAME}-${1}") -ge 1 ]] && { echo_green " ${uni_check}\n"; return 0; } || { echo_red " ${uni_x}\n"; }

    # Ensure we are working in the right context
    eks_set_context "${1}"

    kubectl karmada join \
    --kubeconfig "${KARMADA_HOME}/karmada-apiserver.config" "${CLUSTERS_NAME}-${1}"
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; } || { echo_red " ${uni_x}\n"; exit 5; }
}


# Function to demo deploy a test workload running NGINX with four replicas split equally among two member clusters
function eks_karmada_demo_deploy () {
    # function to demo multi-cluster scheduling with Karmada
    # for the demo purpose we will use only 2 member clusters
    echo_green "${uni_right_triangle} Deploying demo application (nginx) to member clusters ${CLUSTERS_NAME}-member-1 and ${CLUSTERS_NAME}-member-2\n"
    eks_set_context parent

    echo_orange "\t${uni_circle_quarter} check if propagation policy exists"
    # shellcheck disable=SC2046
    if [ $(kubectl --kubeconfig "${KARMADA_HOME}/karmada-apiserver.config" get propagationpolicy | grep -c sample-propagation) -ge 1 ]; then
        echo_green " ${uni_check}\n";
    else
        echo_red " ${uni_x}\n";
        # Create propagation deployment (karmada-demo-nginx) to use two clusters with equal weight
        echo_orange "\t${uni_circle_quarter} create propagation policy for demo nginx deployment to two member cluster"
        {   echo '{ "apiVersion":"policy.karmada.io/v1alpha1",'
            echo '   "kind":"PropagationPolicy",'
            echo '   "metadata": { "name":"sample-propagation" },'
            echo '   "spec":{'
            echo '      "resourceSelectors":[{ "apiVersion":"apps/v1", "kind":"Deployment", "name":"karmada-demo-nginx" }],'
            echo '      "placement":{'
            echo '         "clusterAffinity":{'
            echo "            \"clusterNames\":[\"${CLUSTERS_NAME}-${1}\", \"${CLUSTERS_NAME}-${2}\"]},"
            echo '            "replicaScheduling":{'
            echo '               "replicaDivisionPreference":"Weighted",'
            echo '               "replicaSchedulingType":"Divided",'
            echo '               "weightPreference":{'
            echo '                  "staticWeightList":[{'
            echo "                     \"targetCluster\":{ \"clusterNames\":[\"${CLUSTERS_NAME}-${1}\", \"${CLUSTERS_NAME}-${2}\"]},"
            echo '                     "weight":1}]'
            echo '                }'
            echo '            }'
            echo '        }'
            echo '   }'
            echo '}'
        } > /tmp/$$.karmada-demo.yaml

        kubectl --kubeconfig "${KARMADA_HOME}/karmada-apiserver.config" create -f /tmp/$$.karmada-demo.yaml > /dev/null
        [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; rm -f /tmp/$$.karmada-demo.yaml; } || { echo_red " ${uni_x}\n"; rm -f /tmp/$$.karmada-demo.yaml; }
    fi

    echo_orange "\t${uni_circle_quarter} check if deployment exists"
    # shellcheck disable=SC2046
    if [ $(kubectl --kubeconfig "${KARMADA_HOME}/karmada-apiserver.config" get deployments | grep -c karmada-demo-nginx) -ge 1 ]; then
        echo_green " ${uni_check}\n";
    else
        echo_red " ${uni_x}\n";
        echo_orange "\t${uni_circle_quarter} deploying 4 nginx pods across two clusters"
        kubectl --kubeconfig "${KARMADA_HOME}/karmada-apiserver.config" create deployment karmada-demo-nginx --image nginx --replicas=4 > /dev/null
        [[ $? -eq 0 ]] && { sleep 10; echo_green " ${uni_check}\n"; } || { echo_red " ${uni_x}\n"; exit 5; }
    fi

    echo_orange "\t${uni_circle_quarter} check from parent cluster the deployment across the two member clusters\n"
    kubectl karmada --kubeconfig "${KARMADA_HOME}/karmada-apiserver.config" get pods
}

function eks_karmada_summary () {
    # function that summarises the karmada cluster deployment
    echo -e "\n\n"
    echo_green "${uni_right_triangle}${uni_right_triangle}${uni_right_triangle} Karmada deployment is complete\n"
    echo_orange "\t${uni_right_triangle} Karmada settings directory: ${KARMADA_HOME}\n\n"
    echo_orange "\t${uni_right_triangle} To get info for your cluster status run:\n"
    echo_orange "\t  kubectl --kubeconfig ${KARMADA_HOME}/karmada-apiserver.config get clusters\n\n"
    echo_orange "\t  You can get more info for advanced Karmada capabilities such as multi-cluster scaling, multi-cluster failover or autoscaling across different clusters\n"
    echo_orange "\t  by visiting the official Karmada documentation at https://karmada.io/docs/userguide/ \n"
}

################# 
# Start the run #
#################

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
eks_deploy_ebs parent

# Deploy a network load balancer for the Karmada API server
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
