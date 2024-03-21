package com.myorg;

import io.github.cdklabs.cdknag.NagPackSuppression;
import io.github.cdklabs.cdknag.NagSuppressions;
import software.amazon.awscdk.NestedStack;
import software.amazon.awscdk.services.ec2.*;
import software.amazon.awscdk.services.eks.Cluster;
import software.amazon.awscdk.services.iam.Role;
import software.constructs.Construct;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.Arrays;

import static com.myorg.Constants.*;

public class ManagementHostStack extends NestedStack {

    public ManagementHostStack(Construct scope, String id) {
        this(scope, id, null);
    }

    public ManagementHostStack(Construct scope, String id, ManagementHostProps props) {
        super(scope, id, props);
        createKarmadaManagementHost(props.getVpc(), props.getManagementHostRole(), props.getMastersRoleARN(), props.getCluster(), props.getRegion());
    }

    private void createKarmadaManagementHost(Vpc vpc, Role managementHostRole, String mastersRoleArn, Cluster karmadaCluster, String region) {

        SecurityGroup securityGroup = createBastionHostLinuxSecurityGroup(vpc);
        Instance bastionHostLinux = createBastionHostLinux(vpc, managementHostRole, getMultipartUserData(mastersRoleArn, region), securityGroup);
        bastionHostLinux.getNode().addDependency(karmadaCluster);
//        updateBastionHostLinuxRoleForEKSAccess(cluster, bastionHostLinux, mastersRole);
    }

    private Instance createBastionHostLinux(Vpc vpc, Role managementHostRole, MultipartUserData multipartUserData, SecurityGroup securityGroup) {
        Instance bastionHostLinux = Instance.Builder.create(this, KARMADA_MANAGEMENT_HOST)
                .vpc(vpc)
                .instanceName(KARMADA_MANAGEMENT_HOST)
                .instanceType(InstanceType.of(InstanceClass.T3, InstanceSize.MICRO))
                .machineImage(MachineImage.latestAmazonLinux2023(
                        AmazonLinux2023ImageSsmParameterProps.builder().
                                userData(multipartUserData).
                                build()))
                .blockDevices(Arrays.asList(BlockDevice.builder()
                        .volume(BlockDeviceVolume.ebs(10, EbsDeviceOptions.builder()
                                .encrypted(true)
                                .build()))
                        .deviceName(DEVICE_PATH)
                        .mappingEnabled(Boolean.FALSE)
                        .build()))
                .vpcSubnets(SubnetSelection.builder()
                        .subnetType(SubnetType.PUBLIC)
                        .build())
                .securityGroup(securityGroup)
                .role(managementHostRole)
                .build();
        bastionHostLinux.getNode().addDependency();

        NagSuppressions.addResourceSuppressions(bastionHostLinux,
                Arrays.asList(NagPackSuppression.builder()
                        .id(AWS_SOLUTIONS_EC_28)
                        .reason(AWS_SOLUTIONS_EC2_28_SUPPRESSION)
                        .build(), NagPackSuppression.builder()
                        .id(AWS_SOLUTIONS_EC_29)
                        .reason(AWS_SOLUTIONS_EC2_29_SUPPRESSION)
                        .build()));

        return bastionHostLinux;
    }

    private SecurityGroup createBastionHostLinuxSecurityGroup(Vpc vpc) {
        SecurityGroup securityGroup = new SecurityGroup(this, KARMADA_EC_2_EKS_SG, SecurityGroupProps.builder()
                .vpc(vpc)
                .securityGroupName(KARMADA_EC_2_EKS_SG)
                .allowAllOutbound(Boolean.TRUE)
                .build());
        securityGroup.addIngressRule(Peer.anyIpv4(), Port.tcp(22), SSH_ACCESS);
        NagSuppressions.addResourceSuppressions(securityGroup,
                Arrays.asList(NagPackSuppression.builder()
                        .id(AWS_SOLUTIONS_EC_23)
                        .reason(AWS_SOLUTIONS_EC2_23_SUPPRESSION)
                        .build()));
        return securityGroup;
    }

    private MultipartUserData getMultipartUserData(String masterRoleArn, String region) {
        MultipartUserData multipartUserData = new MultipartUserData();
        UserData userData = getUserDataFromFile(masterRoleArn, region);

        multipartUserData.addUserDataPart(userData, MultipartBody.SHELL_SCRIPT, true);
        return multipartUserData;
    }

    private UserData getUserDataFromFile(String masterRoleArn, String region) {
        UserData userData = UserData.forLinux();

        File file = getFileForUserData();

        try (BufferedReader br = new BufferedReader(new FileReader(file))) {
            String line;
            while ((line = br.readLine()) != null) {
                String lineMasterRoleARN = line.contains(MASTER_ROLE_ARN) ? line.replace(MASTER_ROLE_ARN, masterRoleArn) : line;
                String lineFinal = lineMasterRoleARN.contains(DEPLOYMENT_REGION) ? lineMasterRoleARN.replace(DEPLOYMENT_REGION, region) : lineMasterRoleARN;
                userData.addCommands(lineFinal);
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }

        return userData;
    }

    private File getFileForUserData() {
        URL resource = getClass().getClassLoader().getResource(USER_DATA_FILE);
        try {
            return new File(resource.toURI());
        } catch (URISyntaxException e) {
            throw new RuntimeException(e);
        }
    }
}
