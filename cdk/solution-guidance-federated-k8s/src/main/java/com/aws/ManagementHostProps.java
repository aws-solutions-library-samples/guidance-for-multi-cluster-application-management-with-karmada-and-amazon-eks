package com.aws;

import software.amazon.awscdk.NestedStackProps;
import software.amazon.awscdk.services.ec2.Vpc;
import software.amazon.awscdk.services.eks.Cluster;
import software.amazon.awscdk.services.iam.Role;

public class ManagementHostProps implements NestedStackProps {
    private Vpc vpc;
    private String mastersRoleARN;
    private Role managementHostRole;
    private String region;
    private Cluster cluster;

    public ManagementHostProps vpc(Vpc vpc) {
        this.vpc = vpc;
        return this;
    }

    public ManagementHostProps mastersRoleARN(String mastersRoleARN) {
        this.mastersRoleARN = mastersRoleARN;
        return this;
    }

    public ManagementHostProps managementHostRole(Role managementHostRole) {
        this.managementHostRole = managementHostRole;
        return this;
    }

    public ManagementHostProps region(String region) {
        this.region = region;
        return this;
    }

    public ManagementHostProps cluster(Cluster cluster) {
        this.cluster = cluster;
        return this;
    }

    public Vpc getVpc() {
        return vpc;
    }

    public String getMastersRoleARN() {
        return mastersRoleARN;
    }

    public Role getManagementHostRole() {
        return managementHostRole;
    }

    public String getRegion() {
        return region;
    }

    public Cluster getCluster() {
        return cluster;
    }
}
