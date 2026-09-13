package ai.travelease.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;

/**
 * Configures the AWS Bedrock Runtime client.
 *
 * NOTE: The Bedrock region is intentionally read from BEDROCK_REGION (default us-east-1),
 * NOT from the general AWS_REGION (ap-south-1). Amazon Nova Micro direct on-demand
 * invocation is only available in us-east-1; all other infrastructure stays in ap-south-1.
 *
 * Credentials come from the default AWS SDK credential chain:
 *   - Locally: ~/.aws/credentials or environment variables (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)
 *   - In-cluster: IRSA (IAM Role for Service Account), automatically injected by the EKS pod identity webhook
 *
 * Uses UrlConnectionHttpClient explicitly to avoid Apache HttpClient 5 version conflicts
 * with Spring Boot's managed dependency on the same library.
 */
@Configuration
public class BedrockConfig {

    @Value("${aws.bedrock.region:us-east-1}")
    private String bedrockRegion;

    @Bean
    public BedrockRuntimeClient bedrockRuntimeClient() {
        return BedrockRuntimeClient.builder()
                .region(Region.of(bedrockRegion))
                .httpClient(UrlConnectionHttpClient.builder().build())
                // Credentials resolved automatically from the SDK default chain
                .build();
    }
}
