package com.aws;

import io.github.cdklabs.cdknag.AwsSolutionsChecks;
import io.github.cdklabs.cdknag.NagPackProps;
import io.github.cdklabs.cdknag.NagPackSuppression;
import io.github.cdklabs.cdknag.NagSuppressions;
import software.amazon.awscdk.App;
import software.amazon.awscdk.Aspects;
import software.amazon.awscdk.StackProps;

import java.util.Arrays;

public final class SolutionGuidanceFederatedK8SApp {

    private static final String DESCRIPTION = "Guidance for Federated Kubernetes on AWS (SO9472)";
    private static final String SOLUTION_GUIDANCE_FEDERATED_K_8_S_STACK = "SolutionGuidanceFederatedK8SStack";

    public static void main(final String[] args) {
        App app = new App();

        StackProps stackProps = StackProps.builder()
                .description(DESCRIPTION)
                .build();
        SolutionGuidanceFederatedK8SStack solutionGuidanceFederatedK8SStack = new SolutionGuidanceFederatedK8SStack(app, SOLUTION_GUIDANCE_FEDERATED_K_8_S_STACK, stackProps);
        Aspects.of(app).add(new AwsSolutionsChecks(NagPackProps.builder().verbose(Boolean.TRUE).build()));
        NagPackSuppression iam5Suppresssion = NagPackSuppression.builder().id("AwsSolutions-IAM5").reason("Suppress * in roles for the sake of simplicity").build();
        NagSuppressions.addStackSuppressions(solutionGuidanceFederatedK8SStack,
                Arrays.asList(iam5Suppresssion));
        app.synth();
    }
}
