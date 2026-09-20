package ai.travelease.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;

/**
 * Configures the AWS SecretsManagerClient bean.
 *
 * Secrets loading into the Spring Environment happens earlier in the startup lifecycle
 * via {@link SecretsEnvironmentPostProcessor}, ensuring database credentials and secrets
 * are available before DataSourceAutoConfiguration resolves properties.
 */
@Configuration
public class SecretsConfig {

    @Value("${aws.region:ap-south-1}")
    private String awsRegion;

    @Bean
    public SecretsManagerClient secretsManagerClient() {
        return SecretsManagerClient.builder()
                .region(Region.of(awsRegion))
                .httpClient(UrlConnectionHttpClient.builder().build())
                .build();
    }
}
