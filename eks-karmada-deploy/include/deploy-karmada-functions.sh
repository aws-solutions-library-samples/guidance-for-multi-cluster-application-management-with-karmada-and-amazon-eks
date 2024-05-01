#!/bin/bash
# Author: Alexandros Soumplis (soumplis@amazon.com)
# Description: Functions for the Karmada deployment scripts

# Nice unicode characters
uni_right_triangle="\u25B7"
uni_circle_quarter="\u25D4"
uni_check="\u2714"
uni_x="\u2718"

# We need nice colors for terminals that support it
function echo_red () { echo -ne "\033[0;31m${1}\033[0m"; }
function echo_orange () { echo -ne "\033[0;33m${1}\033[0m"; }
function echo_green () { echo -ne "\033[0;32m${1}\033[0m"; }

function cleanup () {
    # function to clean up after exit
    # shellcheck disable=SC2317
    echo -e "\033[0m\n"
}

function solution_usage_code () {
    # Function that deploys a simple cloudformation stack to create an SSM Parameter for recording purposes of solution usage
    # The use o SSM parameter does not add any security risk and is at no cost
    { echo '{ "AWSTemplateFormatVersion" : "2010-09-09",'
      echo '"Description" : "TR-1234 Multi-cluster Solutions Guidance Tracking",'
      echo '"Resources" : {'
      echo '    "NoopParam": { "Type": "AWS::SSM::Parameter",'
      echo "                   \"Properties\": { \"Name\": \"multi-cluster-management-solution-guidance-${REGION}-${CLUSTERS_NAME}\","
      echo '                                   "Type": "String", "Value": "NoValue" } } } }'
    } > /tmp/$$.karmada-cf.json

    echo_orange "\t${uni_circle_quarter} Deploy dummy cloudformation for solution metadata code recording"
    aws cloudformation deploy --no-fail-on-empty-changeset \
    --region "${REGION}" --template-file /tmp/$$.karmada-cf.json \
    --stack-name "multi-cluster-management-solution-guidance-${REGION}-${CLUSTERS_NAME}" > /dev/null
    [[ $? -eq 0 ]] && { echo_green "\t${uni_check}\n"; rm -f /tmp/$$.karmada-cf.json; } || { echo_orange " ${uni_x}\n"; rm -f /tmp/$$.karmada-cf.json; exit 5; }
}

function running_on () {
    local unameout
    unameout="$(uname -s)"

    case "${unameout}" in
        Linux*)     RUNNINGON=Linux;;
        Darwin*)    RUNNINGON=Mac;;
        CYGWIN*)    RUNNINGON=Cygwin;;
        MINGW*)     RUNNINGON=MinGw;;
        *)          RUNNINGON="UNKNOWN:${unameout}"
    esac
}

function resolve_ip () {
    if [ "${RUNNINGON}" == "Mac" ]; then
        ping -c 1 ${1} | grep "^PING" | cut -f2 -d\( | cut -f1 -d\)        
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        ping -4 -c 1 ${1} | grep "^PING" | cut -f2 -d\( | cut -f1 -d\)
    elif [ "${RUNNINGON}" == "Cygwin" ]; then
        ping -4 -n 1 ${1} | grep "^Pinging" | cut -f2 -d\[ | cut -f1 -d\]
    fi
}

function os_package_manager () {
    if [ "$RUNNINGON" == "Linux" ]; then
        # Check the OS package manager
        command -v apt-get > /dev/null && PKGINSTALL="sudo apt-get -y"
        command -v dnf > /dev/null && PKGINSTALL="sudo dnf -y"
        command -v yum > /dev/null && PKGINSTALL="sudo yum -y"
    else
        echo_red "It seems your are running on a non-supported Linux distribution.\nPlease you have installed the utilities jq, aws cli v2, eksctl, kubectl and run the script again with the -z option"
        exit 1
    fi
}

function install_os_packages () {
    command -v jq > /dev/null && { echo_orange "\t${uni_check} jq already installed\n"; return 0; }

    echo_orange "\t${uni_circle_quarter} jq could not be found, installing it now"
    ${PKGINSTALL} install jq
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

function install_kubectl () {
    command -v kubectl > /dev/null && { echo_orange "\t${uni_check} kubectl already installed\n"; return 0; }

    echo_orange "\t${uni_circle_quarter} kubectl could not be found, installing it now"
    cd /tmp || { echo_red " ${uni_x}Cannot access /tmp directory\n"; exit 5; }
    curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x ./kubectl
    sudo mv kubectl /usr/local/bin
    command -v kubectl > /dev/null && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

function install_eksctl () {
    command -v eksctl > /dev/null 
    if [ $? -eq 0 ]; then
        local latest_eksctl_version="$(curl -sL https://api.github.com/repos/eksctl-io/eksctl/releases | jq -r '.[0].tag_name')"
        [[ "v$(eksctl version)" == "${latest_eksctl_version}" ]] && { echo_orange "\t${uni_check} eksctl already installed and the latest version \n"; return 0; }
    fi

    echo_orange "\t${uni_circle_quarter} eksctl could not be found or is not the latest version, installing/upgrading now"
    cd /tmp || { echo_red " ${uni_x}Cannot access /tmp directory\n"; exit 5; }
    curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
    tar -xzf eksctl_Linux_amd64.tar.gz -C /tmp && rm eksctl_Linux_amd64.tar.gz
    chmod +x eksctl
    sudo mv /tmp/eksctl /usr/local/bin
    command -v eksctl > /dev/null && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

function install_awscli () {
    AWSCLI_MAJOR_VERSION=$(aws --version 2>&1| cut -b9)
    [[ "${AWSCLI_MAJOR_VERSION}" == "2" ]] && { echo_orange "\t${uni_check} aws cli v2 already installed\n"; return 0; }
    [[ "${AWSCLI_MAJOR_VERSION}" == "1" ]] && { echo_orange "\t${uni_circle_quarter} aws cli v1 installed, removing\n"; ${PKGINSTALL} remove awscli; } ### This is dangerous, we need to find something more elegant. Maybe a cli parameter to force remove or abort
    
    echo_orange "\t${uni_circle_quarter} aws cli v2 not installed, installing it now\n"
    cd /tmp || { echo_red " ${uni_x}Cannot access /tmp directory\n"; exit 5; }
    curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
    unzip -o -q awscli-exe-linux-x86_64.zip
    sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
    command -v aws > /dev/null && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

function get_subnets () {
    # function that gets the public and private subnets of the VPC
    # Initialize two local array variables to store the subnet IDs
    local publicsubnets=() 
    local privatesubnets=()

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

function eks_create_cluster () {
    # function that deploys an Amazon EKS cluster with the eksctl utility
    # Check if the cluster already exists
    echo_orange "\t${uni_circle_quarter} check if cluster ${1} exists"

    [[ $(aws eks list-clusters --region "${REGION}" --output text | grep -c "${1}") -ge 1 ]] && { echo_green " ${uni_check}\n"; return 1; } || echo_red " ${uni_x}\n"

    # If the cluster does not exist, create it
    echo_orange "\t${uni_circle_quarter} deploy cluster ${1} (this will take several minutes)\n"
    eksctl create cluster \
        -v 2 --nodes "${CLUSTER_NODES_NUM}" --nodes-min "${CLUSTER_NODES_NUM}" --nodes-max "${CLUSTER_NODES_NUM}" --region "${REGION}" \
        --instance-prefix "${CLUSTERS_NAME}" --version "${EKS_VERSION}" \
        --vpc-private-subnets "${PRIVATE_SUBNETS}" --vpc-public-subnets "${PUBLIC_SUBNETS}" \
        --instance-selector-vcpus "${CLUSTER_VCPUS}" --instance-selector-memory "${CLUSTER_MEMORY}" --instance-selector-cpu-architecture "${CLUSTER_CPU_ARCH}" --auto-kubeconfig \
        --alb-ingress-access --asg-access \
        --name "${1}"
    [[ $? -eq 0 ]] && echo_green "\t${uni_check} Cluster deployed successfully\n" || { echo_orange " ${uni_x}\n"; exit 5; }
    
    echo_orange "\t${uni_circle_quarter} update kube config for ${1}"
    aws eks update-kubeconfig --region "${REGION}" --name "${1}" > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_orange " ${uni_x}\n"; exit 5; }
}

function eks_set_context () {
    # function that sets the right context
    local desirable_context
    # Get the desirable context from the config file and use it
    echo_orange "\t${uni_circle_quarter} switching to the right context"
    desirable_context=$(kubectl config view -o json | jq -r '.contexts[]?.name' | grep "${1}")
    kubectl config use-context "${desirable_context}" > /dev/null
    [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_orange " ${uni_x}\n"; exit 5; }
}

function eks_deploy_ebs () {
    # function that deploys the ebs addon and configures a new gp3 storage class
    local oidc_id

    # Ensure we are working in the right context
    eks_set_context "${1}"

    # Check and associate the IAM OIDC provider
    echo_orange "\t${uni_circle_quarter} Check IAM OIDC provider"
    oidc_id=$(aws eks describe-cluster --region "${REGION}" --query "cluster.identity.oidc.issuer" --name "${1}" --output text | grep "${REGION}" | cut -d '/' -f 5)

    if [ $(aws iam list-open-id-connect-providers --region "${REGION}" | cut -d "/" -f4 | grep -c "${oidc_id}") -ge 1 ]; then
        echo_green " ${uni_check}\n" 
    else
        echo_red " ${uni_x}\n"
        echo_orange "\t${uni_circle_quarter} associate the IAM OIDC provider"
        eksctl utils associate-iam-oidc-provider \
            -v 0 --region "${REGION}" --cluster "${1}" --approve > /dev/null
        [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_orange " ${uni_x}\n"; exit 5; }
    fi

    # Check the IAM service account
    echo_orange "\t${uni_circle_quarter} Check IAM service account"
    if [ $(eksctl get iamserviceaccount  --region "${REGION}" --cluster "${1}" ebs-csi-controller-sa | grep -c ^kube-system) -ge 1 ]; then
        echo_green " ${uni_check}\n"
    else
        echo_red " ${uni_x}\n"
        # Create the IAM service account with a region specific name
        echo_orange "\t${uni_circle_quarter} create IAM service account"
        eksctl create iamserviceaccount \
            -v 0 --region "${REGION}" --cluster "${1}" \
            --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
            --name "ebs-csi-controller-sa" --namespace kube-system --approve --role-only \
            --role-name "AmazonEKS_EBS_CSI_DriverRole_${REGION}_${CLUSTERS_NAME}"  > /dev/null
        [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
    fi

    # Check the EBS CSI driver
    echo_orange "\t${uni_circle_quarter} Check EBS addon"
    if [ $(eksctl get addon --name aws-ebs-csi-driver --cluster "${1}" --region "${REGION}" | grep -c ^aws-ebs-csi-driver) -ge 1 ]; then
        echo_green " ${uni_check}\n"
    else
        echo_red " ${uni_x}\n"
        # Deploy the EBS CSI driver with a region specific name
        echo_orange "\t${uni_circle_quarter} deploy EBS addon"
        eksctl create addon \
            -v 0 --region "${REGION}" --name aws-ebs-csi-driver --cluster "${1}" \
            --service-account-role-arn "arn:aws:iam::${ACCOUNTID}:role/AmazonEKS_EBS_CSI_DriverRole_${REGION}_${CLUSTERS_NAME}" --force  > /dev/null
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
    fi
}

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
    LB_ARN=$(aws elbv2 describe-load-balancers --region "${REGION}" | jq -r '.LoadBalancers[].LoadBalancerArn' | xargs -I {} aws elbv2 describe-tags --region "${REGION}" --resource-arns {} --query "TagDescriptions[?Tags[?Key=='kubernetes.io/service-name'&&Value=='karmada-system/karmada-service-loadbalancer']].ResourceArn" --output text | tail -1)
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

function eks_karmada_plugin_install () {
    # function that installs the karmada plugin for kubectl
    # Check if the plugin is already installed
    command -v kubectl-karmada > /dev/null && { echo_orange "\t${uni_check} kubectl-karmada already installed\n"; return 0; }
    
    # If it is not installed, proceed with the installation
    echo_orange "\n\t${uni_circle_quarter} kubectl-karmada could not be found, installing it now"
    cd /tmp || { echo_red " ${uni_x}Cannot access /tmp directory\n"; exit 5; }
    curl -sL "https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh" | sed 's/mv -i/mv/' | sed 's/< \/dev\/tty//' | sudo bash -s kubectl-karmada
   
    # Check the plugin is deployed successfully
    command -v kubectl-karmada > /dev/null && echo_green " ${uni_check}\n" || { echo_red " ${uni_x}\n"; exit 5; }
}

function eks_karmada_deploy () {
    # function that deploys the karmada cluster
    local karmada_lb_ip
    # Ensure we are working in the right context
    eks_set_context "${1}"
    # Ensure we have the karmada plugin installed
    eks_karmada_plugin_install

    # Check if karmada is already initialised
    echo_orange "\t${uni_circle_quarter} check if karmada is already initialised"
    [[ $(kubectl get deployments -n karmada-system -o name | wc -l) -ge 1 ]] && { echo_green " ${uni_check}\n"; karmadainit = 0; } || { echo_red " ${uni_x}\n"; karmadainit=0; }

    # Check if karmada is initialised correctly if it is already initialised
    if [ karmadainit -eq 0 ]; then 

	    echo_orange "\t${uni_circle_quarter} check if karmada is correctly initialised"
	    karmadapodcounts=$(kubectl get pods --no-headers -n karmada-system | awk '/etcd/ { etcd++ } /apiserver/ { apiserver++ } /aggregated-apiserver/ { aggregated_apiserver++ } /controller-manager/ { controller_manager++ } /scheduler/ { scheduler++ } /webhook/ { webhook++ } END { printf "%d %d %d %d %d %d", etcd, apiserver, aggregated_apiserver, controller_manager, scheduler, webhook }')
    	read etcd_count apiserver_count aggregated_apiserver_count controller_manager_count scheduler_count webhook_count <<< "$karmadapodcounts"

    	# Check that we have all the required pods running
    	if [ "$etcd_count" -lt "3" ] || [ "$apiserver_count" -lt "3" ] || [ "$aggregated_apiserver_count" -lt "1" ] || [ "$controller_manager_count" -lt "1" ] || [ "$scheduler_count" -lt "1" ] || [ "$webhook_count" -lt "1" ]; then
		echo_red " ${uni_x} Karmada deployment seems not to have the correct pods running, please check and run the script again\n"
		exit 5
    	else
		echo_green " ${uni_check}\n"
		return 0
    	fi
    fi

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

function eks_karmada_register () {
    # function that register an eks cluster to karmada
    # Ensure we have the karmada plugin installed
    eks_karmada_plugin_install

    # Check if the cluster is already registered on the parent cluster
    eks_set_context "${2}"
    echo_orange "\t${uni_circle_quarter} check if ${1} is already registered to Karmada cluster"
    [[ $(kubectl --kubeconfig "${KARMADA_HOME}/karmada-apiserver.config" get clusters | grep -c "${1}") -ge 1 ]] && { echo_green " ${uni_check}\n"; return 0; } || { echo_red " ${uni_x}\n"; }

    # Ensure we are working in the right context
    eks_set_context "${1}"

    kubectl karmada join \
    --kubeconfig "${KARMADA_HOME}/karmada-apiserver.config" "${1}"
    [[ $? -eq 0 ]] && { echo_green " ${uni_check}\n"; } || { echo_red " ${uni_x}\n"; exit 5; }
}

function eks_karmada_demo_deploy () {
    # function to demo multi-cluster scheduling with Karmada
    # for the demo purpose we will use only 2 member clusters
    echo_green "${uni_right_triangle} Deploying demo application (nginx) to member clusters ${1} and ${2}\n"
    eks_set_context "${3}"

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
            echo "            \"clusterNames\":[\"${1}\", \"${2}\"]},"
            echo '            "replicaScheduling":{'
            echo '               "replicaDivisionPreference":"Weighted",'
            echo '               "replicaSchedulingType":"Divided",'
            echo '               "weightPreference":{'
            echo '                  "staticWeightList":[{'
            echo "                     \"targetCluster\":{ \"clusterNames\":[\"${1}\", \"${2}\"]},"
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

function eks_karmada_delete () {
    # function that deletes the karmada cluster
    for cluster in ${CLUSTER_NAMES}; do
        # delete eks cluster
        echo_orange "\t${uni_circle_quarter} deleting EKS cluster ${cluster}\n"
        eksctl delete cluster --name "${cluster}" --region "${REGION}"
        [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || echo_red " ${uni_x}\n"       
    done

    # delete karmada home directory but check if it is a directory first
    if [[ -d "${KARMADA_HOME}" ]]; then
        echo_orange "\t${uni_circle_quarter} deleting Karmada home directory ${KARMADA_HOME}\n"
        rm -rf "${KARMADA_HOME}"
        [[ $? -eq 0 ]] && echo_green " ${uni_check}\n" || echo_red " ${uni_x}\n"
    fi
    exit 0
}

function delete_deployment () {
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
    
    [[ "${confirm}" == "iReallyMeanIt" ]] && eks_karmada_delete || { echo_red "You don't really mean it. Exiting...\n"; exit 1;}
}
