package com.aws;

import org.junit.jupiter.api.Test;
import software.amazon.awscdk.App;
import software.amazon.awscdk.assertions.Template;

public class SolutionGuidanceFederatedK8SStackTest {

    @Test
    public void testStack() {
        App app = new App();
        SolutionGuidanceFederatedK8SStack stack = new SolutionGuidanceFederatedK8SStack(app, "test");
        Template template = Template.fromStack(stack);
    }
}
