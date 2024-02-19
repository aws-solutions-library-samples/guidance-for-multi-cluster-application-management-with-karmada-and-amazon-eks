package com.myorg;

import software.amazon.awscdk.App;
import software.amazon.awscdk.assertions.Template;
import software.amazon.awscdk.assertions.Match;
import java.io.IOException;

import java.util.HashMap;

import org.junit.jupiter.api.Test;

public class SolutionGuidanceFederatedK8SStackTest {

    @Test
    public void testStack() {
        App app = new App();
        SolutionGuidanceFederatedK8SStack stack = new SolutionGuidanceFederatedK8SStack(app, "test");
        Template template = Template.fromStack(stack);
    }
}
