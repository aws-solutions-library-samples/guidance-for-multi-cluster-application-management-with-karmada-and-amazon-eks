package com.myorg;


import software.amazon.awscdk.NestedStackProps;
import software.amazon.awscdk.services.ec2.SecurityGroup;
import software.amazon.awscdk.services.ec2.Vpc;

public class ResourceNestedStackProps implements NestedStackProps {

    private String clusterName;
    private Vpc vpc;
    private SecurityGroup securityGroup;

    public ResourceNestedStackProps clusterName(String clusterName) {
        this.clusterName = clusterName;
        return this;
    }

    public ResourceNestedStackProps vpc(Vpc vpc) {
        this.vpc = vpc;
        return this;
    }

    public ResourceNestedStackProps securityGroup(SecurityGroup securityGroup) {
        this.securityGroup = securityGroup;
        return this;
    }

    public String getClusterName() {
        return clusterName;
    }

    public Vpc getVpc() {
        return vpc;
    }

    public SecurityGroup getSecurityGroup() {
        return securityGroup;
    }

}
