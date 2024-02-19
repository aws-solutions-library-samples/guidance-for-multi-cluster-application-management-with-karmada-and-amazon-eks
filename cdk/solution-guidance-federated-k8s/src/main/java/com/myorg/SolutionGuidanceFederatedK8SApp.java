package com.myorg;

import software.amazon.awscdk.App;
import software.amazon.awscdk.Environment;
import software.amazon.awscdk.StackProps;

public final class SolutionGuidanceFederatedK8SApp {

    private static final String DESCRIPTION = "Guidance for Federated K8s Stack";
    private static final String SOLUTION_GUIDANCE_FEDERATED_K_8_S_STACK = "SolutionGuidanceFederatedK8SStack";

    public static void main(final String[] args) {
        App app = new App();

        StackProps stackProps = StackProps.builder()
                .description(DESCRIPTION)
                .build();
        new SolutionGuidanceFederatedK8SStack(app, SOLUTION_GUIDANCE_FEDERATED_K_8_S_STACK, stackProps);

        app.synth();
    }
}
