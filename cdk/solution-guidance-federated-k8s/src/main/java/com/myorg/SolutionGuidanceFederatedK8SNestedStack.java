package com.myorg;

import software.amazon.awscdk.NestedStack;
import software.amazon.awscdk.lambdalayer.kubectl.KubectlLayer;
import software.amazon.awscdk.services.autoscaling.AutoScalingGroup;
import software.amazon.awscdk.services.autoscaling.UpdatePolicy;
import software.amazon.awscdk.services.ec2.*;
import software.amazon.awscdk.services.eks.*;
import software.amazon.awscdk.services.iam.*;
import software.constructs.Construct;

import java.util.Arrays;

import static com.myorg.Constants.*;
import static com.myorg.Constants.CHILD_EKSASG;

public class SolutionGuidanceFederatedK8SNestedStack extends NestedStack {

    public SolutionGuidanceFederatedK8SNestedStack(final Construct parent, final String id, final ResourceNestedStackProps props) {
        super(parent, id, props);
        Role mastersRole = Role.Builder.create(this, MASTERS_ROLE_CHILD_CLUSTER)
//                .assumedBy(new ArnPrincipal(ARN_AWS_IAM_USER))
                .assumedBy(new ServicePrincipal("eks.amazonaws.com"))
                .roleName(MASTERS_ROLE_CHILD_CLUSTER)
                .build();
        createChildCluster(props.getClusterName(), props.getVpc(), props.getSecurityGroup(), mastersRole);
    }

    private void createChildCluster(final String clusterName, final Vpc vpc, final SecurityGroup securityGroup, Role mastersRole) {
        Cluster cluster = Cluster.Builder.create(this, clusterName)
                .clusterName(clusterName)
                .vpc(vpc)
                .securityGroup(securityGroup)
                .version(KubernetesVersion.V1_27)
                .kubectlLayer(new KubectlLayer(this, KUBECTL_LAYER_1))
                .defaultCapacityInstance(InstanceType.of(InstanceClass.M5, InstanceSize.LARGE))
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

        mastersRole.addManagedPolicy(ManagedPolicy.fromAwsManagedPolicyName(ADMINISTRATOR_ACCESS));
        mastersRole.addToPolicy(PolicyStatement.Builder.create()
                .actions(Arrays.asList(EKS_ACCESS_KUBERNETES_API, EKS_DESCRIBE, EKS_LIST, STS_ASSUME_ROLE))
                .resources(Arrays.asList(cluster.getClusterArn()))
                .build());
        mastersRole.grantAssumeRole(cluster.getAdminRole());

        AutoScalingGroup eksAsg = AutoScalingGroup.Builder
                .create(this, CHILD_EKSASG)
                .autoScalingGroupName(CHILD_EKSASG)
                .vpc(vpc)
                .securityGroup(securityGroup)
                .vpcSubnets(SubnetSelection.builder().subnetType(SubnetType.PRIVATE_WITH_EGRESS).build())
                .minCapacity(3)
                .maxCapacity(3)
                .instanceType(
                        InstanceType.of(InstanceClass.M5,
                                InstanceSize.LARGE))
                .machineImage(
                        EksOptimizedImage.Builder
                                .create()
                                .kubernetesVersion(
                                        KubernetesVersion.V1_27.getVersion())
                                .nodeType(NodeType.STANDARD)
                                .build())
                .updatePolicy(UpdatePolicy.rollingUpdate())
                .build();

        cluster.connectAutoScalingGroupCapacity(eksAsg, AutoScalingGroupOptions
                .builder()
                .build());
    }


}
