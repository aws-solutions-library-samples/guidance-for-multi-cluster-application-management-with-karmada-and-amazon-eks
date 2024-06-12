package com.aws;

import io.github.cdklabs.cdknag.NagPackSuppression;
import io.github.cdklabs.cdknag.NagSuppressions;
import org.jetbrains.annotations.NotNull;
import software.amazon.awscdk.NestedStack;
import software.amazon.awscdk.lambdalayer.kubectl.KubectlLayer;
import software.amazon.awscdk.services.autoscaling.AutoScalingGroup;
import software.amazon.awscdk.services.autoscaling.BlockDevice;
import software.amazon.awscdk.services.autoscaling.BlockDeviceVolume;
import software.amazon.awscdk.services.autoscaling.EbsDeviceVolumeType;
import software.amazon.awscdk.services.autoscaling.UpdatePolicy;
import software.amazon.awscdk.services.autoscaling.EbsDeviceOptions;
import software.amazon.awscdk.services.ec2.*;
import software.amazon.awscdk.services.eks.OpenIdConnectProvider;
import software.amazon.awscdk.services.eks.*;
import software.amazon.awscdk.services.iam.*;
import software.constructs.Construct;

import java.util.Arrays;
import java.util.Map;

import static com.aws.Constants.*;

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

        NagSuppressions.addStackSuppressions(this,
                Arrays.asList(NagPackSuppression.builder().id("AwsSolutions-EKS1").reason("AwsSolutions-EKS1 Suppression").build()));
        NagSuppressions.addStackSuppressions(this,
                Arrays.asList(NagPackSuppression.builder().id("AwsSolutions-L1").reason("AwsSolutions-L1 Suppression").build()), Boolean.TRUE);
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
                .assumedBy(new ServicePrincipal(EKS_AMAZONAWS_COM))
                .roleName(MASTERS_ROLE)
                .build();
        NagSuppressions.addResourceSuppressions(mastersRole,
                Arrays.asList(NagPackSuppression.builder()
                        .id(AWS_SOLUTIONS_IAM_4)
                        .reason(AWS_SOLUTIONS_IAM_4_SUPPRESSION)
                        .build()));

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
        NagSuppressions.addResourceSuppressions(cluster,
                Arrays.asList(NagPackSuppression.builder()
                        .id("AwsSolutions-EKS1")
                        .reason("AwsSolutions-EKS1 Suppresions")
                        .build()));

        return cluster;
    }

    private AutoScalingGroup createEKSAutoScalingGroup(Vpc vpc, SecurityGroup securityGroup) {
        AutoScalingGroup eksAsg = AutoScalingGroup.Builder
                .create(this, KARMADA_EKSASG)
                .autoScalingGroupName(KARMADA_EKSASG)
                .vpc(vpc)
                .securityGroup(securityGroup)
                .vpcSubnets(SubnetSelection.builder().subnetType(SubnetType.PUBLIC).build())
                .blockDevices(Arrays.asList(getBlockDevice()))
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

    @NotNull
    private static BlockDevice getBlockDevice() {
        return BlockDevice.builder().deviceName(DEVICE_PATH).volume(BlockDeviceVolume.ebs(10, EbsDeviceOptions.builder()
                .volumeType(EbsDeviceVolumeType.GP3)
                .encrypted(Boolean.TRUE)
                .build())).build();
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
                .securityGroupName(KARMADA_SG)
                .allowAllOutbound(Boolean.TRUE)
                .build());
        karmadaClusterSecurityGroup.addIngressRule(Peer.anyIpv4(), Port.tcp(TCP_PORT), SG_DESCRIPTION);
        karmadaClusterSecurityGroup.addIngressRule(Peer.ipv4(KARMADA_CIDR_BLOCK), Port.tcp(HTTPS_PORT), SG_DESCRIPTION);

        NagSuppressions.addResourceSuppressions(karmadaClusterSecurityGroup,
                Arrays.asList(NagPackSuppression.builder()
                        .id(AWS_SOLUTIONS_EC_23)
                        .reason(AWS_SOLUTIONS_EC2_23_SUPPRESSION)
                        .build()));
        return karmadaClusterSecurityGroup;
    }
}
