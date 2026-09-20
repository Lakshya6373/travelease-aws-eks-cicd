package ai.travelease.config;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueResponse;

import java.util.HashMap;
import java.util.Map;

/**
 * Loads AWS Secrets Manager secrets directly into the Spring Environment
 * BEFORE any DataSource, Flyway, or other beans are initialized.
 *
 * This ensures that:
 *   1. ${DB_HOST}, ${DB_PORT}, ${DB_NAME}, ${DB_USER}, ${DB_PASSWORD}, and ${JWT_SECRET}
 *      are populated in the Environment before DataSourceAutoConfiguration resolves them.
 *   2. No External Secrets Operator (ESO) is required in the cluster.
 *   3. If SECRET_NAME is not set (e.g. in local development or unit tests), this is a no-op
 *      and default values from application.yml / docker-compose are used.
 */
@Order(Ordered.HIGHEST_PRECEDENCE)
public class SecretsEnvironmentPostProcessor implements EnvironmentPostProcessor {

    private static final Logger log = LoggerFactory.getLogger(SecretsEnvironmentPostProcessor.class);

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        String secretName = environment.getProperty("SECRET_NAME");
        if (secretName == null || secretName.isBlank()) {
            secretName = environment.getProperty("aws.secrets.secret-name");
        }
        if (secretName == null || secretName.isBlank()) {
            secretName = System.getenv("SECRET_NAME");
        }

        if (secretName == null || secretName.isBlank()) {
            log.info("SecretsEnvironmentPostProcessor: SECRET_NAME not set — using local defaults from application.yml");
            return;
        }

        String awsRegion = environment.getProperty("AWS_REGION");
        if (awsRegion == null || awsRegion.isBlank()) {
            awsRegion = environment.getProperty("aws.region", "ap-south-1");
        }

        try {
            log.info("SecretsEnvironmentPostProcessor: fetching secret '{}' from AWS Secrets Manager ({})",
                    secretName, awsRegion);

            try (SecretsManagerClient client = SecretsManagerClient.builder()
                    .region(Region.of(awsRegion))
                    .httpClient(UrlConnectionHttpClient.builder().build())
                    .build()) {

                GetSecretValueResponse response = client.getSecretValue(
                        GetSecretValueRequest.builder().secretId(secretName).build());

                ObjectMapper objectMapper = new ObjectMapper();
                JsonNode root = objectMapper.readTree(response.secretString());

                Map<String, Object> props = new HashMap<>();
                addIfPresent(props, "DB_HOST",     root, "db_host");
                addIfPresent(props, "DB_PORT",     root, "db_port");
                addIfPresent(props, "DB_NAME",     root, "db_name");
                addIfPresent(props, "DB_USER",     root, "db_user");
                addIfPresent(props, "DB_PASSWORD", root, "db_password");
                addIfPresent(props, "JWT_SECRET",  root, "jwt_secret");

                // Also populate spring.datasource and jwt properties directly
                if (props.containsKey("DB_HOST")) {
                    String host = (String) props.get("DB_HOST");
                    String port = (String) props.getOrDefault("DB_PORT", "5432");
                    String dbName = (String) props.getOrDefault("DB_NAME", "travelease");
                    props.put("spring.datasource.url", "jdbc:postgresql://" + host + ":" + port + "/" + dbName);
                }
                if (props.containsKey("DB_USER")) {
                    props.put("spring.datasource.username", props.get("DB_USER"));
                }
                if (props.containsKey("DB_PASSWORD")) {
                    props.put("spring.datasource.password", props.get("DB_PASSWORD"));
                }
                if (props.containsKey("JWT_SECRET")) {
                    props.put("app.jwt.secret", props.get("JWT_SECRET"));
                }

                // Add as highest priority so these values override application.yml defaults
                environment.getPropertySources().addFirst(
                        new MapPropertySource("aws-secrets-manager", props));

                log.info("SecretsEnvironmentPostProcessor: successfully loaded {} secrets from '{}' into Spring Environment",
                        props.size(), secretName);
            }

        } catch (Exception ex) {
            log.error("SecretsEnvironmentPostProcessor: failed to load secret '{}' from AWS Secrets Manager: {}",
                    secretName, ex.getMessage());
            throw new IllegalStateException(
                    "Failed to fetch secret '" + secretName + "' from AWS Secrets Manager: " + ex.getMessage(), ex);
        }
    }

    private void addIfPresent(Map<String, Object> props, String key, JsonNode root, String jsonField) {
        if (root.has(jsonField) && !root.get(jsonField).isNull()) {
            props.put(key, root.get(jsonField).asText());
        }
    }
}
