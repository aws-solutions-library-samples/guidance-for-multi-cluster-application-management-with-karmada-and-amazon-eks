package com.myorg;

import software.amazon.awscdk.NestedStackProps;
import software.amazon.awscdk.services.ec2.Vpc;

public class KarmadaClusterProps implements NestedStackProps {

    private Vpc vpc;
    private String region;
    private String accountId;

    public KarmadaClusterProps vpc(Vpc vpc) {
        this.vpc = vpc;
        return this;
    }

    public KarmadaClusterProps region(String region) {
        this.region = region;
        return this;
    }

    public KarmadaClusterProps accountId(String accountId) {
        this.accountId = accountId;
        return this;
    }

    public Vpc getVpc() {
        return vpc;
    }

    public String getRegion() {
        return region;
    }

    public String getAccountId() {
        return accountId;
    }
}
