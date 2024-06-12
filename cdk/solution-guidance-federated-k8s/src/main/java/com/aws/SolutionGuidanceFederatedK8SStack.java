package com.aws;

import io.github.cdklabs.cdknag.NagPackSuppression;
import io.github.cdklabs.cdknag.NagSuppressions;
import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;
import software.amazon.awscdk.services.ec2.*;
import software.constructs.Construct;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import static com.aws.Constants.*;

public class SolutionGuidanceFederatedK8SStack extends Stack {

    private final Vpc vpc;
    private final String accountId;
    private final String region;

    public SolutionGuidanceFederatedK8SStack(final Construct parent, final String id) {
        this(parent, id, null);
    }

    public SolutionGuidanceFederatedK8SStack(final Construct parent, final String id, final StackProps props) {
        super(parent, id, props);

        this.accountId = getEnvVariable(CDK_DEFAULT_ACCOUNT, ACCOUNT_ID);
        this.region = getEnvVariable(CDK_DEFAULT_ACCOUNT1, DEFAULT_REGION);

        final SubnetConfiguration publicSubnetConfiguration = createSubnetConfiguration(KARMADA_PUBLIC_1, 20, Boolean.FALSE);
        final SubnetConfiguration privateSubnetConfiguration = createSubnetConfiguration(KARMADA_PRIVATE_1, 24, Boolean.TRUE);
        this.vpc = createVPC(publicSubnetConfiguration, privateSubnetConfiguration);

        KarmadaClusterProps karmadaClusterProps = new KarmadaClusterProps().vpc(vpc)
                .region(this.region)
                .accountId(this.accountId);
        KarmadaClusterStack karmadaClusterStack = new KarmadaClusterStack(this, KARMADA_CLUSTER_STACK, karmadaClusterProps);

        ManagementHostProps managementHostProps = new ManagementHostProps()
                .managementHostRole(karmadaClusterStack.getManagementHostRole())
                .region(this.region)
                .mastersRoleARN(karmadaClusterStack.getMastersRoleARN())
                .cluster(karmadaClusterStack.getKarmadaCluster())
                .vpc(vpc);
        new ManagementHostStack(this, MANAGEMENT_HOST_STACK, managementHostProps);

//        ResourceNestedStackProps resourceNestedStackProps = new ResourceNestedStackProps().clusterName(CHILD_CLUSTER).vpc(vpc).securityGroup(securityGroup);
//        new SolutionGuidanceFederatedK8SNestedStack(this, CHILD_CLUSTERNESTED_STACK_ID, resourceNestedStackProps);

        NagSuppressions.addStackSuppressions(this,
                Arrays.asList(NagPackSuppression.builder().id(AWS_SOLUTIONS_IAM_5).reason(SUPPRESS_IN_ROLES_FOR_THE_SAKE_OF_SIMPLICITY).build(),
                        NagPackSuppression.builder().id(AWS_SOLUTIONS_IAM_4).reason(AWS_SOLUTIONS_IAM_4_SUPPRESSION).build(),
                        NagPackSuppression.builder().id("AwsSolutions-AS3").reason("AwsSolutions-AS3 Suppresions").build()), Boolean.TRUE);
    }

    private static String getEnvVariable(String CDK_DEFAULT_ACCOUNT, String accountId) {
        return System.getenv(CDK_DEFAULT_ACCOUNT) != null ? System.getenv(CDK_DEFAULT_ACCOUNT) : accountId;
    }

    public Vpc getVpc() {
        return vpc;
    }

    private SubnetConfiguration createSubnetConfiguration(final String subnetName, Number cidrMask, Boolean privateSubnet) {
        return SubnetConfiguration.builder()
                .cidrMask(cidrMask)
                .name(subnetName)
                .subnetType(privateSubnet ? SubnetType.PRIVATE_WITH_EGRESS : SubnetType.PUBLIC)
                .build();
    }

    private Vpc createVPC(SubnetConfiguration publicSubnet, SubnetConfiguration privateSubnet) {
        Map<String, FlowLogOptions> flowLog = new HashMap<>();
        flowLog.put(FLOW_LOG_CLOUD_WATCH, FlowLogOptions.builder()
                .trafficType(FlowLogTrafficType.REJECT)
                .maxAggregationInterval(FlowLogMaxAggregationInterval.ONE_MINUTE)
                .build());
        return Vpc.Builder.create(this, KARMADA_VPC)
                .ipAddresses(IpAddresses.cidr(KARMADA_CIDR_BLOCK))
                .vpcName(KARMADA_VPC)
                .flowLogs(flowLog)
                .availabilityZones(Arrays.asList(this.region + REGION_AZA, this.region + REGION_AZB, this.region + REGION_AZC))
                .natGateways(1)
                .subnetConfiguration(Arrays.asList(publicSubnet, privateSubnet))
                .build();
    }

}
