package com.myorg;

import software.amazon.awscdk.services.ec2.InstanceClass;
import software.amazon.awscdk.services.ec2.InstanceSize;
import software.amazon.awscdk.services.eks.KubernetesVersion;

import java.util.Arrays;
import java.util.List;

public class Constants {

    static final String KARMADA_VPC = "karmada-vpc";
    static final String KARMADA_PUBLIC_1 = "karmada-public-1";
    static final String KARMADA_PRIVATE_1 = "karmada-private-1";
    static final String KARMADA_CIDR_BLOCK = "10.1.0.0/16";

    static final String REGION_AZA = "a";
    static final String REGION_AZB = "b";
    static final String REGION_AZC = "c";

//    public static final String ARN_AWS_IAM_USER = "arn:aws:iam::<ACCOUNT_ID>:user/<USER>";
//    public static final String ARN_AWS_IAM = "arn:aws:iam::";
//    public static final String ARN_AWS_USER = ":user/";
//        <USER>";

    static final String KARMADA_SG = "karmada-sg";
    static final int TCP_PORT = 32443;
    static final int HTTPS_PORT = 443;
    static final String KARMADA_CLUSTER = "karmada-eks-cluster-parent";
    static final String SG_DESCRIPTION = "Access to the KARMADA clusters";
    static final String MASTERS_ROLE = "MastersRole";


    static final String OPEN_ID_CONNECT_PROVIDER = "OpenIdConnectProvider";
    static final String EKS_CLUSTER_ADDON_ROLE = "EKSClusterAddonRole";
    static final String AMAZON_EBSCSI_DRIVER_POLICY = "AmazonEBSCSIDriverPolicy";
    static final String ARN_AWS_IAM_AWS_POLICY_SERVICE_ROLE_AMAZON_EBSCSIDRIVER_POLICY = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy";
    static final String AWS_EBS_CSI_DRIVER = "aws-ebs-csi-driver";
    static final String EBS_CSI_ADDON = "ebs-csi-addon";
    static final String OVERWRITE = "OVERWRITE";
    static final String EKS_BUILD_VERSION = "v1.21.0-eksbuild.1";

    static final String KARMADA_EKSASG = "KarmadaEKSASG";
    static final String CHILD_EKSASG = "ClildEKSASG";
    static final String KUBECTL_LAYER = "kubectlLayer";
    static final String KUBECTL_LAYER_1 = "kubectlLayer1";
    static final String KARMADA_MANAGEMENT_HOST = "KarmadaManagementHost";
    static final KubernetesVersion KUBERNETES_VERSION = KubernetesVersion.V1_28;


    static final String KARMADA_EC_2_EKS_SG = "karmada-ec2-eks-sg";
    static final String SSH_ACCESS = "SSH Access";
    static final String CLUSTER_ID = "karmada-kubernetes";
    static final String ADMINISTRATOR_ACCESS = "AdministratorAccess";
    static final String EKS_ACCESS_KUBERNETES_API = "eks:AccessKubernetesApi";
    static final String EKS_DESCRIBE = "eks:Describe*";
    static final String EKS_LIST = "eks:List*";
    static final String STS_ASSUME_ROLE = "sts:AssumeRole";
    static final String DEVICE_PATH = "/dev/xvda";
    static final InstanceClass INSTANCE_CLASS = InstanceClass.M5;
    static final InstanceSize INSTANCE_SIZE = InstanceSize.LARGE;

    static final String CHILD_CLUSTERNESTED_STACK_ID = "childClusternestedStackId";
    static final String CHILD_CLUSTER = "child-eks-cluster";
    static final String MASTERS_ROLE_CHILD_CLUSTER = "MastersRoleChildCluster";

    static final String USER_DATA_FILE = "userdata.txt";
    static final String MASTER_ROLE_ARN = "MASTER_ROLE_ARN";
    static final String DEPLOYMENT_REGION = "REGION";

    static final String MANAGEMENT_HOST_ROLE = "ManagementHostRole";
    static final String EC2_SERVICE_PRINCIPAL = "ec2.amazonaws.com";

    static final List<String> EKS_POLICIES_LIST = Arrays.asList("eks:*");
    static final List<String> EC2_POLICIES_LIST = Arrays.asList("ec2:DescribeVpcs",
            "ec2:DescribeRouteTables",
            "ec2:DescribeInternetGateways",
            "ec2:DescribeSubnets");
    static final List<String> S3_POLICIES_LIST = Arrays.asList("s3:*");
    static final List<String> IAM_POLICIES_LIST = Arrays.asList("eks:ListClusters",
            "iam:GetRole",
            "iam:CreateRole",
            "iam:AttachRolePolicy",
            "iam:TagRole",
            "eks:DescribeAddon",
            "eks:DescribeAddonConfiguration",
            "eks:DescribeAddonVersions");
    static final List<String> CLOUDFORMATION_POLICIES_LIST = Arrays.asList("cloudformation:ListStacks",
            "cloudformation:CreateStack", "cloudformation:DescribeStacks"/*TODO: to be removed*/);
    static final List<String> ALL_RESOURCES_LIST = Arrays.asList("*");
    static final List<String> LOAD_BALANCING_POLICIES_LIST = Arrays.asList("elasticloadbalancing:DescribeLoadBalancers",
            "elasticloadbalancing:DescribeTags", "cloudformation:CreateChangeSet");
    static final List<String> OPEN_ID_POLICIES_LIST = Arrays.asList("iam:GetOpenIDConnectProvider");

    static final String KARMADA_CLUSTER_STACK = "KarmadaClusterStack";
    static final String MANAGEMENT_HOST_STACK = "ManagementHostStack";

    static final String ARN_AWS_CLOUDFORMATION = "arn:aws:cloudformation:";
    static final String STACK = ":stack/*/*";

    static final String DEFAULT_REGION = "eu-west-2";
    static final String ACCOUNT_ID = "ACCOUNT_ID";
    static final String CDK_DEFAULT_ACCOUNT = "CDK_DEFAULT_ACCOUNT";
    static final String CDK_DEFAULT_ACCOUNT1 = "CDK_DEFAULT_REGION";

}
