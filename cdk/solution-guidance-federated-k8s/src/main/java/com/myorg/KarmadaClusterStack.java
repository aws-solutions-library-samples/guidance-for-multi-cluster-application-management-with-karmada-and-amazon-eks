package com.myorg;

import software.amazon.awscdk.NestedStack;
import software.amazon.awscdk.lambdalayer.kubectl.KubectlLayer;
import software.amazon.awscdk.services.autoscaling.AutoScalingGroup;
import software.amazon.awscdk.services.autoscaling.UpdatePolicy;
import software.amazon.awscdk.services.ec2.*;
import software.amazon.awscdk.services.eks.OpenIdConnectProvider;
import software.amazon.awscdk.services.eks.*;
import software.amazon.awscdk.services.iam.*;
import software.constructs.Construct;

import java.util.Arrays;
import java.util.Map;

import static com.myorg.Constants.*;

public class KarmadaClusterStack extends NestedStack {

    private Cluster karmadaCluster;
    private Role managementHostRole;
    private String mastersRoleARN;

    public KarmadaClusterStack(Construct scope, String id) {
        this(scope, id, null);
    }

    public KarmadaClusterStack(Construct scope, String id, KarmadaClusterProps props) {
        super(scope, id, props);

        Role mastersRole = createMastersRole();
        this.mastersRoleARN = mastersRole.getRoleArn();
        final SecurityGroup securityGroup = createSecurityGroup(props.getVpc());
        this.karmadaCluster = createEKSCluster(KARMADA_CLUSTER, props.getVpc(), securityGroup, mastersRole);
        this.managementHostRole = createManagementHostRole(karmadaCluster, mastersRole, props.getRegion(), props.getAccountId());
    }

    public Cluster getKarmadaCluster() {
        return karmadaCluster;
    }

    public Role getManagementHostRole() {
        return managementHostRole;
    }

    public String getMastersRoleARN() {
        return mastersRoleARN;
    }

    private Role createMastersRole() {
        Role mastersRole = Role.Builder.create(this, MASTERS_ROLE)
                //.assumedBy(new ArnPrincipal(ARN_AWS_IAM + accountId + ARN_AWS_USER + ))
                .assumedBy(new ServicePrincipal("eks.amazonaws.com"))
                .roleName(MASTERS_ROLE)
                .build();
        return mastersRole;
    }

    private Cluster createEKSCluster(final String clusterName, final Vpc vpc, final SecurityGroup securityGroup, Role mastersRole) {
        Cluster cluster = createCluster(clusterName, vpc, securityGroup, mastersRole);
        updateMastersRole(mastersRole, cluster);
        cluster.connectAutoScalingGroupCapacity(createEKSAutoScalingGroup(vpc, securityGroup), AutoScalingGroupOptions
                .builder()
                .build());

        OpenIdConnectPrincipal principal = createOpenIDPrincipal(cluster);
        Role role = createClusterAddonRole(principal);
        CfnAddon ebsAddon = createEBSAddon(cluster, role);
        addManifest(cluster);

        return cluster;
    }

    private CfnAddon createEBSAddon(Cluster cluster, Role role) {
        return CfnAddon.Builder.create(this, EBS_CSI_ADDON)
                .addonName(AWS_EBS_CSI_DRIVER)
                .clusterName(cluster.getClusterName())
                .resolveConflicts(OVERWRITE)
                .addonVersion(EKS_BUILD_VERSION)
                .serviceAccountRoleArn(role.getRoleArn())
                .build();
    }

    private Role createClusterAddonRole(OpenIdConnectPrincipal principal) {
        Role role = Role.Builder.create(this, EKS_CLUSTER_ADDON_ROLE)
                .roleName(EKS_CLUSTER_ADDON_ROLE)
                .managedPolicies(Arrays.asList(ManagedPolicy.fromManagedPolicyArn(this,
                        AMAZON_EBSCSI_DRIVER_POLICY,
                        ARN_AWS_IAM_AWS_POLICY_SERVICE_ROLE_AMAZON_EBSCSIDRIVER_POLICY)))
                .assumedBy(principal)
                .build();
        return role;
    }

    private OpenIdConnectPrincipal createOpenIDPrincipal(Cluster cluster) {
        OpenIdConnectProvider provider = OpenIdConnectProvider.Builder.create(this, OPEN_ID_CONNECT_PROVIDER)
                .url(cluster.getClusterOpenIdConnectIssuerUrl())
                .build();
        OpenIdConnectPrincipal principal = new OpenIdConnectPrincipal(provider);
        return principal;
    }

    private void updateMastersRole(Role mastersRole, Cluster cluster) {
        mastersRole.addManagedPolicy(ManagedPolicy.fromAwsManagedPolicyName(ADMINISTRATOR_ACCESS));
        mastersRole.addToPolicy(PolicyStatement.Builder.create()
                .actions(Arrays.asList(EKS_ACCESS_KUBERNETES_API, EKS_DESCRIBE, EKS_LIST, STS_ASSUME_ROLE))
                .resources(Arrays.asList(cluster.getClusterArn()))
                .build());
        mastersRole.grantAssumeRole(cluster.getAdminRole());
    }

    private Cluster createCluster(String clusterName, Vpc vpc, SecurityGroup securityGroup, Role mastersRole) {
        Cluster cluster = Cluster.Builder.create(this, clusterName)
                .clusterName(clusterName)
                .vpc(vpc)
                .securityGroup(securityGroup)
                .version(KUBERNETES_VERSION)
                .kubectlLayer(new KubectlLayer(this, KUBECTL_LAYER))
                .defaultCapacityInstance(InstanceType.of(INSTANCE_CLASS, INSTANCE_SIZE))
                .defaultCapacityType(DefaultCapacityType.NODEGROUP)
                .clusterLogging(Arrays.asList(ClusterLoggingTypes.API,
                        ClusterLoggingTypes.AUDIT,
                        ClusterLoggingTypes.AUTHENTICATOR,
                        ClusterLoggingTypes.CONTROLLER_MANAGER,
                        ClusterLoggingTypes.SCHEDULER))
                .defaultCapacity(0)
                .mastersRole(mastersRole)
                .outputMastersRoleArn(Boolean.TRUE)
                .build();
        return cluster;
    }

    private AutoScalingGroup createEKSAutoScalingGroup(Vpc vpc, SecurityGroup securityGroup) {
        AutoScalingGroup eksAsg = AutoScalingGroup.Builder
                .create(this, KARMADA_EKSASG)
                .autoScalingGroupName(KARMADA_EKSASG)
                .vpc(vpc)
                .securityGroup(securityGroup)
                .vpcSubnets(SubnetSelection.builder().subnetType(SubnetType.PUBLIC).build())
                .minCapacity(3)
                .maxCapacity(3)
                .instanceType(
                        InstanceType.of(INSTANCE_CLASS, INSTANCE_SIZE))
                .machineImage(EksOptimizedImage.Builder
                        .create()
                        .kubernetesVersion(KUBERNETES_VERSION.getVersion())
                        .nodeType(NodeType.STANDARD)
                        .build())
                .updatePolicy(UpdatePolicy.rollingUpdate())
                .build();
        return eksAsg;
    }

    private void addManifest(Cluster cluster) {
        Map<String, Object> deployment = Map.of(
                "apiVersion", "storage.k8s.io/v1",
                "kind", "StorageClass",
                "metadata", Map.of("name", "ebs-sc"),
                "provisioner", "ebs.csi.aws.com",
                "volumeBindingMode", "WaitForFirstConsumer",
                "parameters", Map.of(
                        "type", "gp3"));

        cluster.addManifest(CLUSTER_ID, deployment);
    }

    private Role createManagementHostRole(Cluster cluster, Role mastersRole, String region, String accountId) {
        Role bastionHostLinuxRole = Role.Builder.create(this, MANAGEMENT_HOST_ROLE).assumedBy(new ServicePrincipal(EC2_SERVICE_PRINCIPAL)).build();
        mastersRole.getAssumeRolePolicy().
                addStatements(createPolicyStatementforBastionHostLinuxRolePermission(bastionHostLinuxRole.getRoleArn()));
        bastionHostLinuxRole.addToPolicy(PolicyStatement.Builder
                .create()
                .effect(Effect.ALLOW)
                .resources(Arrays.asList(cluster.getClusterArn()))
                .actions(EKS_POLICIES_LIST)
                .build());

        //TODO: delete that
        bastionHostLinuxRole.addToPolicy(PolicyStatement.Builder
                .create()
                .effect(Effect.ALLOW)
                .resources(ALL_RESOURCES_LIST)
                .actions(IAM_POLICIES_LIST)
                .build());

        bastionHostLinuxRole.addToPolicy(PolicyStatement.Builder
                .create()
                .effect(Effect.ALLOW)
                .resources(ALL_RESOURCES_LIST)
                .actions(S3_POLICIES_LIST)
                .build());

        bastionHostLinuxRole.addToPolicy(PolicyStatement.Builder
                .create()
                .effect(Effect.ALLOW)
                .resources(ALL_RESOURCES_LIST)
                .actions(EC2_POLICIES_LIST)
                .build());

        bastionHostLinuxRole.addToPolicy(PolicyStatement.Builder
                .create()
                .effect(Effect.ALLOW)
                .resources(Arrays.asList(ARN_AWS_CLOUDFORMATION + region + ":" + accountId + STACK))
                .actions(CLOUDFORMATION_POLICIES_LIST)
                .build());

        bastionHostLinuxRole.addToPolicy(PolicyStatement.Builder
                .create()
                .effect(Effect.ALLOW)
                .resources(ALL_RESOURCES_LIST)
                .actions(LOAD_BALANCING_POLICIES_LIST)
                .build());

        bastionHostLinuxRole.addToPolicy(PolicyStatement.Builder
                .create()
                .effect(Effect.ALLOW)
                .resources(ALL_RESOURCES_LIST)
                .actions(OPEN_ID_POLICIES_LIST)
                .build());
        return bastionHostLinuxRole;
    }

    private PolicyStatement createPolicyStatementforBastionHostLinuxRolePermission(String bastionHostLinuxRoleArn) {
        return PolicyStatement.Builder.
                create().
                principals(Arrays.asList(new ArnPrincipal(bastionHostLinuxRoleArn))).
                actions(Arrays.asList(STS_ASSUME_ROLE)).
                build();
    }

    private SecurityGroup createSecurityGroup(Vpc vpc) {
        SecurityGroup karmadaClusterSecurityGroup = new SecurityGroup(this, KARMADA_SG, SecurityGroupProps.builder()
                .vpc(vpc)
                .allowAllOutbound(Boolean.TRUE)
                .build());
        karmadaClusterSecurityGroup.addIngressRule(Peer.anyIpv4(), Port.tcp(TCP_PORT), SG_DESCRIPTION);
        karmadaClusterSecurityGroup.addIngressRule(Peer.ipv4(KARMADA_CIDR_BLOCK), Port.tcp(HTTPS_PORT), SG_DESCRIPTION);
        return karmadaClusterSecurityGroup;
    }
}
