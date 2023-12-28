#!/bin/bash
# Author: Alexandros Soumplis (soumplis@amazon.com)

# Define default values for required parameters. These can be overriden with command line parameters
EKS_VERSION="$(aws eks describe-addon-versions | jq -r ".addons[] | .addonVersions[] | .compatibilities[] | .clusterVersion" | sort | uniq | tail -1)"  
VPC_NAME="vpc-eks"
REGION="eu-north-1"
CLUSTERS_NAME="karmada"
CLUSTER_NODES_NUM=3 # You need at least three worker nodes for Karmada HA api server
CLUSTER_VCPUS=2
CLUSTER_MEMORY=4
CLUSTER_CPU_ARCH="x86_64"
MEMBER_CLUSTER_NUM=2
KARMADA_HOME="${HOME}/.karmada"

# Let's parse any command line parameters
while getopts ":e:v:r:c:n:p:m:a:s:k:h" opt; do
  case $opt in
    e) EKS_VERSION="${OPTARG}";;
    v) VPC_NAME="${OPTARG}";;
    r) REGION="${OPTARG}";;
    c) CLUSTERS_NAME="${OPTARG}";;
    n) CLUSTER_NODES_NUM="${OPTARG}";;
    p) CLUSTER_VCPUS="${OPTARG}";;
    m) CLUSTER_MEMORY="${OPTARG}";;
    a) CLUSTER_CPU_ARCH="${OPTARG}";;
    s) MEMBER_CLUSTER_NUM="${OPTARG}";;
    k) KARMADA_HOME="${OPTARG}";;
    h) 
        echo "Usage: $0 [args]"
        echo ""
        echo "Arguments:"
        echo "  -e  EKS version                    (default: 1.28)"
        echo "  -v  VPC name                       (default: vpc-manual)"
        echo "  -r  Region                         (default: eu-north-1)"
        echo "  -c  Cluster name                   (default: karmada)"
        echo "  -n  Number of cluster nodes        (default: 3)"
        echo "  -p  Cluster VCPUs                  (default: 2)"
        echo "  -m  Cluster memory                 (default: 4)"
        echo "  -a  Cluster CPU architecture       (default: x86_64)"
        echo "  -s  Number of member cluster       (default: 2)"
        echo "  -k  Karmada home directory         (default: ~/.karmada)"
        echo "  -h  Display this help message"
        exit 0;;
    :) echo "Option -${OPTARG} requires an argument. Use -h for more information"; exit 1;;
    *) echo "Invalid option: -${OPTARG}. Use -h for more information"; exit 1;;
    \?) echo "Invalid option: -${OPTARG}. Use -h for more information"; exit 1;;
  esac
done


function cleanup () {
    echo -e "\033[0m\n"
}

trap cleanup EXIT

# Find the correct package manager for the OS
function os_package_manager () {
    # Check the OS package manager
    command -v apt-get > /dev/null && PKGINSTALL="sudo apt-get -y"
    command -v dnf > /dev/null && PKGINSTALL="sudo dnf -y"
    command -v yum > /dev/null && PKGINSTALL="sudo yum -y"
}

function install_os_packages () {
    command -v jq > /dev/null && { echo_orange "\t${uni_check} jq already installed\n"; return 0; }

    echo_orange "\t${uni_circle_quarter} jq could not be found, installing it now"
    ${PKGINSTALL} install jq
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

# Install kubectl
function install_kubectl () {
    command -v kubectl > /dev/null && { echo_orange "\t${uni_check} kubectl already installed\n"; return 0; }

    echo_orange "\t${uni_circle_quarter} kubectl could not be found, installing it now"
    cd /tmp
    curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x ./kubectl
    sudo mv kubectl /usr/local/bin
    command -v kubectl > /dev/null && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

# Install eksctl
function install_eksctl () {
    command -v eksctl > /dev/null && { echo_orange "\t${uni_check} eksctl already installed\n"; return 0; }

    echo_orange "\n\t${uni_circle_quarter} eksctl could not be found, installing it now"
    cd /tmp
    curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
    tar -xzf eksctl_Linux_amd64.tar.gz -C /tmp && rm eksctl_Linux_amd64.tar.gz
    chmod +x eksctl
    sudo mv /tmp/eksctl /usr/local/bin
    command -v eksctl > /dev/null && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

# Install awscli v2
function install_awscli () {
    AWSCLI_MAJOR_VERSION=$(aws --version 2>&1| cut -b9)
    [[ "${AWSCLI_MAJOR_VERSION}" == "2" ]] && { echo_orange "\t${uni_check} aws cli v2 already installed\n"; return 0; }
    [[ "${AWSCLI_MAJOR_VERSION}" == "1" ]] && { echo_orange "\t${uni_circle_quarter} aws cli v1 installed, removing\n"; ${PKGINSTALL} remove awscli; } ### This is dangerous, we need to find something more elegant. Maybe a cli parameter to force remove or abort
    
    echo_orange "\t${uni_circle_quarter} aws cli v2 not installed, installing it now\n"
    cd /tmp
    curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
    unzip -o -q awscli-exe-linux-x86_64.zip
    sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
    command -v aws > /dev/null && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}


# get all subnets from the vpc and classify into public and private
function get_subnets () {
    # function that gets the public and private subnets of the VPC
    # Initialize two local array variables to store the subnet IDs
    local publicsubnets=() 
    local privatesubnets=()

    # Get all subnets in the VPC
    local subnets=$(aws ec2 describe-subnets --region ${REGION} --filters "Name=vpc-id,Values=${VPCID}" --query 'Subnets[].SubnetId' --output text)
    # Get all subnets with explicit associations in route tables
    local associated_subnets=$(aws ec2 describe-route-tables --region ${REGION} --filters "Name=vpc-id,Values=${VPCID}" --query 'RouteTables[].Associations[].SubnetId' --output text)
    
    # Get internet gateways in the VPC
    local igw=$(aws ec2 describe-internet-gateways --region ${REGION} --filters "Name=attachment.vpc-id,Values=${VPCID}" --query 'InternetGateways[].InternetGatewayId' --output text)
    # Get route tables in the VPC with an igw attached
    local igw_routes=$(aws ec2 describe-route-tables --region ${REGION} --filters "Name=vpc-id,Values=${VPCID}" --query "RouteTables[?Routes[?GatewayId==\`${igw}\`]].RouteTableId" --output text)
    # Get the main route table for the explicit rules
    local main_route=$(aws ec2 describe-route-tables --region ${REGION} --filters "Name=vpc-id,Values=${VPCID}" --query "RouteTables[?Associations[?Main==\`true\`]].RouteTableId" --output text)

    # Loop through subnets
    for subnet in ${subnets}; do
        # Check if the subnet has an explicit association with a route table
        if [[ "${associated_subnets}" =~ "${subnet}" ]]; then
            # the subnet has an explicit association, check if it is associated with a public route table
            [[ "${igw_routes}" =~ "$(aws ec2 describe-route-tables --region ${REGION} --filters "Name=association.subnet-id,Values=${subnet}" --query 'RouteTables[].RouteTableId' --output text)" ]] && publicsubnets+=("${subnet}") || privatesubnets+=("${subnet}") 
        else
            # the subnet has no explicit association, it is implicitly associated with the main route table
            # if the main route table has an igw attached then the subnet is public, else it's private
            grep -qw ${main_route} <<< "${igw_routes}" && publicsubnets+=("${subnet}") || privatesubnets+=("${subnet}")
        fi
    done

    # check that we have private and public subnets available and build lists in csv format
    [[ ${#privatesubnets[@]} -le 0 ]] && { echo_red "\t${uni_x} No private subnets found, exiting\n"; exit 5; } || PRIVATE_SUBNETS=$(echo ${privatesubnets[@]} | tr ' ' ',')
    [[ ${#publicsubnets[@]} -le 0 ]] && { echo_red "\t${uni_x} No public subnets found, exiting\n"; exit 5; }  || PUBLIC_SUBNETS=$(echo ${publicsubnets[@]} | tr ' ' ',') 
}

function eks_create_cluster () {
    # function that deploys an Amazon EKS cluster with the eksctl utility
    # Check if the cluster already exists
    echo_orange "\t${uni_circle_quarter} check if cluster ${CLUSTERS_NAME}-${1} exists"

    [[ $(aws eks list-clusters --output text | grep "${CLUSTERS_NAME}-${1}" | wc -l) -ge 1 ]] && { echo_green " ${uni_check}\n"; return 1; } || echo_red " ${uni_x}\n"

    # If the cluster does not exist, create it
    echo_orange "\t${uni_circle_quarter} deploy cluster ${CLUSTERS_NAME}-${1} (this will take several minutes)\n"
    eksctl create cluster \
        -v 2 --nodes ${CLUSTER_NODES_NUM} --nodes-min ${CLUSTER_NODES_NUM} --nodes-max ${CLUSTER_NODES_NUM} --region ${REGION} \
        --instance-prefix ${CLUSTERS_NAME} --version ${EKS_VERSION} \
        --vpc-private-subnets ${PRIVATE_SUBNETS} --vpc-public-subnets ${PUBLIC_SUBNETS} \
        --instance-selector-vcpus ${CLUSTER_VCPUS} --instance-selector-memory ${CLUSTER_MEMORY} --instance-selector-cpu-architecture ${CLUSTER_CPU_ARCH} --auto-kubeconfig \
        --alb-ingress-access --asg-access \
        --name "${CLUSTERS_NAME}-${1}"
    [[ $? -eq 0 ]] && echo_green "\t${uni_check} Cluster deployed successfully\n" || { echo_orange " ${uni_x}\n"; exit 5; }
    
    echo_orange "\t${uni_circle_quarter} update kube config for ${CLUSTERS_NAME}-${1}"
    aws eks update-kubeconfig --region ${REGION} --name "${CLUSTERS_NAME}-${1}" > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_orange " ${uni_x}\n"; exit 5; }
}

function eks_set_context () {
    # function that sets the right context
    # Get the desirable context from the config file and use it
    echo_orange "\t${uni_circle_quarter} switching to the right context"
    local desirable_context=$(kubectl config view -o json | jq -r '.contexts[]?.name' | grep "${CLUSTERS_NAME}-${1}")
    kubectl config use-context ${desirable_context} > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_orange " ${uni_x}\n"; exit 5; }
}

function eks_deploy_ebs () {
    # function that deploys the ebs addon and configures a new gp3 storage class
    # Ensure we are working in the right context
    eks_set_context ${1}

    # Associate the IAM OIDC provider
    echo_orange "\t${uni_circle_quarter} associate the IAM OIDC provider"
    eksctl utils associate-iam-oidc-provider \
        -v 0 --region ${REGION} --cluster "${CLUSTERS_NAME}-${1}" --approve > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_orange " ${uni_x}\n"; exit 5; }

    # Create the IAM service account
    echo_orange "\t${uni_circle_quarter} create IAM service account"
    eksctl create iamserviceaccount \
        -v 0 --region ${REGION} --cluster "${CLUSTERS_NAME}-${1}" \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --name ebs-csi-controller-sa --namespace kube-system --approve --role-only \
        --role-name AmazonEKS_EBS_CSI_DriverRole  > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }

    # Deploy the EBS CSI driver
    echo_orange "\t${uni_circle_quarter} deploy EBS addon"
    eksctl create addon \
        -v 0 --region ${REGION} --name aws-ebs-csi-driver --cluster "${CLUSTERS_NAME}-${1}" \
        --service-account-role-arn arn:aws:iam::${ACCOUNTID}:role/AmazonEKS_EBS_CSI_DriverRole --force  > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }

    # Create the gp3 storage class
    echo_orange "\t${uni_circle_quarter} create gp3 ebs storage class"
    echo '{ "apiVersion": "storage.k8s.io/v1",' > /tmp/$$.ebs-sc.json
    echo '  "kind": "StorageClass",' >> /tmp/$$.ebs-sc.json
    echo '  "metadata": { "name": "ebs-sc" },' >> /tmp/$$.ebs-sc.json
    echo '  "provisioner": "ebs.csi.aws.com",' >> /tmp/$$.ebs-sc.json
    echo '  "volumeBindingMode": "WaitForFirstConsumer",' >> /tmp/$$.ebs-sc.json
    echo '  "parameters": { "type": "gp3" }' >> /tmp/$$.ebs-sc.json
    echo '}' >> /tmp/$$.ebs-sc.json

    kubectl apply -f /tmp/$$.ebs-sc.json > /dev/null
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; rm -f /tmp/$$.ebs-sc.json; } || { echo_red " ${uni_x}\n"; rm -f /tmp/$$.ebs-sc.json; exit 5; }
}

function eks_karmada_ns () {
    # function that checks (and creates if not exists) the karmada-system namespace
    # Ensure we are working in the right context
    eks_set_context ${1}

    # Check if the namespace exists
    echo_orange "\t${uni_circle_quarter} check if namespace karmada-system exists"
    kubectl get namespace --no-headers | grep karmada-system 2>&1 > /dev/null
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; return 0; } || { echo_red " ${uni_x}\n"; }

    # If the namespace does not exist, create it
    echo_orange "\t${uni_circle_quarter} create Karmada namespace"
    kubectl create namespace karmada-system > /dev/null
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; } || { echo_red " ${uni_x}\n"; }
}

function eks_lb_deploy () {
    # function that deploys a network load balancer in the karmada-system namespace
    # Ensure we are working in the right context
    eks_set_context ${1}

    # Ensure we have the karmada-system namespace in place
    eks_karmada_ns ${1}

    # Define the load balancer config and deploy
    echo_orange "\t${uni_circle_quarter} deploy Karmada network load balancer"

    echo '{ "apiVersion": "v1",' > /tmp/$$.karmada-lb.json
    echo '  "kind": "Service",' >> /tmp/$$.karmada-lb.json
    echo '  "metadata": { "name": "karmada-service-loadbalancer", "namespace": "karmada-system",' >> /tmp/$$.karmada-lb.json
    echo '                "annotations": {' >> /tmp/$$.karmada-lb.json
    echo '                  "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",' >> /tmp/$$.karmada-lb.json
    echo '                  "service.beta.kubernetes.io/aws-load-balancer-name": "karmada-lb",' >> /tmp/$$.karmada-lb.json
    echo '                  "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing",' >> /tmp/$$.karmada-lb.json
    echo '                  "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type": "ip" }' >> /tmp/$$.karmada-lb.json
    echo '},' >> /tmp/$$.karmada-lb.json
    echo '"spec": { "type": "LoadBalancer",' >> /tmp/$$.karmada-lb.json
    echo '          "selector": { "app": "karmada-apiserver" },' >> /tmp/$$.karmada-lb.json
    echo '          "ports": [{ "protocol": "TCP", "port": 32443, "targetPort": 5443 }] }' >> /tmp/$$.karmada-lb.json
    echo '}' >> /tmp/$$.karmada-lb.json

    kubectl apply -f /tmp/$$.karmada-lb.json > /dev/null
    [[ $? -eq 0 ]] && { sleep 5; echo_green " ${uni_check}\n"; rm -f /tmp/$$.karmada-lb.json; } || { echo_red " ${uni_x}\n"; rm -f /tmp/$$.karmada-lb.json; exit 5; }
    
    # Define the KARMADA_LB variable
    KARMADA_LB=$(kubectl get svc -n karmada-system karmada-service-loadbalancer -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}')
}

function eks_karmada_plugin_install () {
    # function that installs the karmada plugin for kubectl
    # Check if the plugin is already installed
    command -v kubectl-karmada > /dev/null && { echo_orange "\t${uni_check} kubectl-karmada already installed\n"; return 0; }
    
    # If it is not installed, proceed with the installation
    echo_orange "\n\t${uni_circle_quarter} kubectl-karmada could not be found, installing it now"
    cd /tmp
    curl -sL "https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh" | sudo bash -s kubectl-karmada
   
    # Check the plugin is deployed successfully
    command -v kubectl-karmada > /dev/null && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

function eks_karmada_deploy () {
    # function that deploys the karmada cluster
    # Ensure we are working in the right context
    eks_set_context ${1}
    # Ensure we have the karmada plugin installed
    eks_karmada_plugin_install

    # Check if karmada is already initialised
    echo_orange "\t${uni_circle_quarter} check if karmada is already initialised"
    [[ $(kubectl get deployments -n karmada-system -o name | wc -l) -ge 1 ]] && { echo_green " ${uni_check}\n"; return 0; } || { echo_red " ${uni_x}\n"; }

    # Deploy the Karmada cluster
    # we use the public IP address of the first network load balancer instance as the kube api does not support multiple IP addresses
    # This is required for the init phase and internal karmada sync operations. All user-facing operation go through the load balancer DNS name
    echo_orange "\t${uni_circle_quarter} deploy Karmada api server"
    #local worker_node_ip=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[?(@.type=='ExternalIP')].address}")
    local karmada_lb_ip=$(getent hosts ${KARMADA_LB} | head -1 | cut -f1 -d' ')
    kubectl karmada init \
     --karmada-apiserver-advertise-address ${karmada_lb_ip} \
     --karmada-apiserver-replicas 3 --etcd-replicas 3 \
     --etcd-storage-mode PVC --storage-classes-name ebs-sc \
     --cert-external-dns="*.elb.${KARMADA_REGION}.amazonaws.com" \
     --karmada-data "${KARMADA_HOME}" --karmada-pki="${KARMADA_HOME}/pki"
    
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; } || { echo_red " ${uni_x}\n"; exit 5; }
}

function eks_karmada_register () {
    # function that register an eks cluster to karmada
    # Ensure we have the karmada plugin installed
    eks_karmada_plugin_install

    # Check if the cluster is already registered
    eks_set_context parent
    echo_orange "\t${uni_circle_quarter} check if ${CLUSTERS_NAME}-${1} is already registered to Karmada cluster"
    [[ $(kubectl --kubeconfig ${KARMADA_HOME}/karmada-apiserver.config get clusters | grep ${CLUSTERS_NAME}-${1} | wc -l) -ge 1 ]] && { echo_green " ${uni_check}\n"; return 0; } || { echo_red " ${uni_x}\n"; }

    # Ensure we are working in the right context
    eks_set_context ${1}

    kubectl karmada join \
    --kubeconfig ${KARMADA_HOME}/karmada-apiserver.config "${CLUSTERS_NAME}-${1}"
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; } || { echo_red " ${uni_x}\n"; exit 5; }
}

function eks_karmada_demo_deploy () {
    # function to demo multi-cluster scheduling with Karmada
    # for the demo purpose we will use only 2 member clusters
    echo_green "${uni_right_triangle} Deploying demo application (nginx) to member clusters ${CLUSTERS_NAME}-member-1 and ${CLUSTERS_NAME}-member-2\n"
    eks_set_context parent

    echo_orange "\t${uni_circle_quarter} check if propagation policy exists"
    if [ $(kubectl --kubeconfig /home/karmadacdk/.karmada/karmada-apiserver.config get propagationpolicy | grep sample-propagation | wc -l) -ge 1 ]; then
        echo_green " ${uni_check}\n";
    else
        echo_red " ${uni_x}\n";
        # Create propagation deployment (karmada-demo-nginx) to use two clusters with equal weight
        echo_orange "\t${uni_circle_quarter} create propagation policy for demo nginx deployment to two member cluster"
        cat <<-EOF > /tmp/$$.karmada-demo.yaml
        {
            "apiVersion":"policy.karmada.io/v1alpha1",
            "kind":"PropagationPolicy",
            "metadata":{
                "name":"sample-propagation"
            },
            "spec":{
                "resourceSelectors":[
                    {
                        "apiVersion":"apps/v1",
                        "kind":"Deployment",
                        "name":"karmada-demo-nginx"
                    }
                ],
                "placement":{
                    "clusterAffinity":{
                        "clusterNames":[
                            "${CLUSTERS_NAME}-${1}",
                            "${CLUSTERS_NAME}-${2}"
                        ]
                    },
                    "replicaScheduling":{
                        "replicaDivisionPreference":"Weighted",
                        "replicaSchedulingType":"Divided",
                        "weightPreference":{
                            "staticWeightList":[
                                {
                                    "targetCluster":{
                                        "clusterNames":[
                                            "${CLUSTERS_NAME}-${1}",
                                            "${CLUSTERS_NAME}-${2}"
                                        ]
                                    },
                                    "weight":1
                                }
                            ]
                        }
                    }
                }
            }
        }
EOF

        kubectl --kubeconfig ${KARMADA_HOME}/karmada-apiserver.config create -f /tmp/$$.karmada-demo.yaml > /dev/null
        [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; rm -f /tmp/$$.karmada-demo.yaml; } || { echo_red " ${uni_x}\n"; rm -f /tmp/$$.karmada-demo.yaml; }
    fi

    echo_orange "\t${uni_circle_quarter} check if deployment exists"
    if [ $(kubectl --kubeconfig /home/karmadacdk/.karmada/karmada-apiserver.config get deployments | grep karmada-demo-nginx | wc -l) -ge 1 ]; then
        echo_green " ${uni_check}\n";
    else
        echo_red " ${uni_x}\n";
        echo_orange "\t${uni_circle_quarter} deploying 4 nginx pods across two clusters"
        kubectl --kubeconfig ${KARMADA_HOME}/karmada-apiserver.config create deployment karmada-demo-nginx --image nginx --replicas=4 > /dev/null
        [[ $? -eq 0 ]] && { sleep 10; echo_green " ${uni_check}\n"; } || { echo_red " ${uni_x}\n"; exit 5; }
    fi

    for i in {1..2}; do
        echo_orange "\t${uni_circle_quarter} check deployment in cluster ${CLUSTERS_NAME}-member-${i}\n"
        eks_set_context member-${i}
        kubectl get pod -l app=karmada-demo-nginx
    done
}

function eks_karmada_summary () {
    # function that summarises the karmada cluster deployment
    echo -e "\n\n"
    echo_green "${uni_right_triangle}${uni_right_triangle}${uni_right_triangle} Karmada deployment is complete!\n"
    echo_orange "\t${uni_right_triangle} Karmada settings directory: ${KARMADA_HOME}\n\n"
    echo_orange "\t${uni_right_triangle} To get info for your cluster status run:\n"
    echo_orange "\t  kubectl --kubeconfig ${KARMADA_HOME}/karmada-apiserver.config get clusters\n\n"
    echo_orange "\t  You can get more info for advanced Karmada capabilities such as multi-cluster scaling, multi-cluster failover or autoscaling across different clusters\n"
    echo_orange "\t  by visiting the official Karmada documentation at https://karmada.io/docs/userguide/ \n"
}

################# 
# Start the run #
#################

# We need nice colors for terminals that support it
function echo_red () { echo -ne "\033[0;31m${1}\033[0m"; }
function echo_orange () { echo -ne "\033[0;33m${1}\033[0m"; }
function echo_green () { echo -ne "\033[0;32m${1}\033[0m"; }

# We also like nice unicode characters
uni_right_triangle="\u25B7"
uni_circle_quarter="\u25D4"
uni_check="\u2714"
uni_x="\u2718"
uni_exclamation="\u2755"

# show the values of the parameters
echo "Ready to run the Karmada deployment script with the following parameters:"
echo -n "  Amazon EKS version: "; echo_orange "${EKS_VERSION}\n";
echo -n "  VPC name: "; echo_orange "${VPC_NAME}\n";
echo -n "  Region: "; echo_orange "${REGION}\n";
echo -n "  Cluster name prefix: "; echo_orange "${CLUSTERS_NAME}\n";
echo -n "  Cluster nodes: "; echo_orange "${CLUSTER_NODES_NUM}\n";
echo -n "  Cluster nodes CPUs: "; echo_orange "${CLUSTER_VCPUS}\n";
echo -n "  Cluster nodes memory: "; echo_orange "${CLUSTER_MEMORY}\n";
echo -n "  Cluster CPU arch: "; echo_orange "${CLUSTER_CPU_ARCH}\n";
echo -n "  Number of karmada member clusters: "; echo_orange "${MEMBER_CLUSTER_NUM}\n";
echo -n "  Karmada HOME dir: "; echo_orange "${KARMADA_HOME}\n";
echo "Press enter to continue or Ctrl-C to abort"
read -r

echo_green "${uni_right_triangle} Checking prerequisites\n"
os_package_manager
install_os_packages
install_kubectl
install_eksctl
install_awscli

echo_green "${uni_right_triangle} Prepare some parameters\n"
VPCID=$(aws ec2 describe-vpcs --region ${REGION} --filter "Name=tag:Name,Values=*${VPC_NAME}*" --query "Vpcs[].VpcId" --output text)
[[ -z "${VPCID}" ]] && { echo_red "\t${uni_x} VPC ${VPC_NAME} not found, exiting\n"; exit 5; }
echo_orange "\t${uni_check} VPC ID: ${VPCID}\n"
get_subnets
echo_orange "\t${uni_check} Private Subnets: ${PRIVATE_SUBNETS}\n"
echo_orange "\t${uni_check} Public Subnets: ${PUBLIC_SUBNETS}\n"
ACCOUNTID=$(aws sts get-caller-identity --query "Account" --output text)
echo_orange "\t${uni_check} Account ID: ${ACCOUNTID}\n"

echo_green "${uni_right_triangle} Creating the Karmada parent cluster\n"
eks_create_cluster parent
echo_green "${uni_right_triangle} Deploy the EBS addon for Karmada HA\n"
eks_deploy_ebs parent

echo_green "${uni_right_triangle} Creating the Karmada member clusters\n"
for i in $(seq 1 ${MEMBER_CLUSTER_NUM}); do
    eks_create_cluster "member-${i}"
done

echo_green "${uni_right_triangle} Deploy Karmada Load Balancer\n"
eks_lb_deploy parent
echo_orange "\t${uni_check} Karmada Load Balancer DNS name: ${KARMADA_LB}\n"
echo_green "${uni_right_triangle} Deploy Karmada Load Balancer\n"
eks_karmada_deploy parent

for i in $(seq 1 ${MEMBER_CLUSTER_NUM}); do
    echo_green "${uni_right_triangle} Registering the Karmada member cluster ${CLUSTERS_NAME}-member-${i} to Karmada\n"
    eks_karmada_register "member-${i}"
done

[[ ${MEMBER_CLUSTER_NUM} -ge 2 ]] && eks_karmada_demo_deploy member-1 member-2
echo_green "${uni_right_triangle} Switching to the Karmada parent cluster context\n"
eks_set_context parent
eks_karmada_summary
exit 0
