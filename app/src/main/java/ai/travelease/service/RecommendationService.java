package ai.travelease.service;

import ai.travelease.domain.Category;
import ai.travelease.domain.Destination;
import ai.travelease.dto.RecommendationResult;
import ai.travelease.repository.DestinationRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelRequest;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelResponse;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Integrates with Amazon Bedrock (Nova Micro) to classify a user's travel query
 * into destination categories and return matching real destinations from the database.
 *
 * Fallback behaviour: if Bedrock is disabled or throws any exception, returns ALL
 * destinations unfiltered, with no AI blurb — the page always renders.
 */
@Service
public class RecommendationService {

    private static final Logger log = LoggerFactory.getLogger(RecommendationService.class);

    // Single-call prompt: returns both categories AND a one-liner blurb template in one JSON object
    private static final String PROMPT_TEMPLATE = """
            You are a travel category classifier. Given the traveler's request below, respond with ONLY a JSON object in this exact shape:
            {
              "categories": ["CATEGORY1", "CATEGORY2"],
              "blurb": "One short sentence describing why these places match the request."
            }
            Categories must be chosen ONLY from this list: [MOUNTAIN, BEACH, CITY, ADVENTURE, CULTURAL, WILDLIFE, HONEYMOON].
            Do not include any prose outside the JSON object.
            Traveler request: %s""";

    private final BedrockRuntimeClient bedrockClient;
    private final DestinationRepository destinationRepository;
    private final ObjectMapper objectMapper;

    @Value("${app.recommendation.enabled:true}")
    private boolean recommendationEnabled;

    @Value("${aws.bedrock.model-id:amazon.nova-micro-v1:0}")
    private String modelId;

    public RecommendationService(BedrockRuntimeClient bedrockClient,
                                 DestinationRepository destinationRepository,
                                 ObjectMapper objectMapper) {
        this.bedrockClient = bedrockClient;
        this.destinationRepository = destinationRepository;
        this.objectMapper = objectMapper;
    }

    /**
     * Returns AI-recommended destinations matching the user's query.
     * Falls back to all destinations (no blurb) if the feature is disabled or Bedrock errors.
     */
    public List<RecommendationResult> recommend(String userQuery) {
        if (!recommendationEnabled) {
            log.info("Recommendation feature disabled; returning all destinations unfiltered.");
            return allDestinationsNoBlurb();
        }

        try {
            String prompt = String.format(PROMPT_TEMPLATE, userQuery);

            // Build Nova Micro request body (messages API format)
            String requestBody = objectMapper.writeValueAsString(java.util.Map.of(
                    "messages", List.of(java.util.Map.of(
                            "role", "user",
                            "content", List.of(java.util.Map.of("type", "text", "text", prompt))
                    )),
                    "inferenceConfig", java.util.Map.of("maxTokens", 300, "temperature", 0.0)
            ));

            InvokeModelRequest request = InvokeModelRequest.builder()
                    .modelId(modelId)
                    .contentType("application/json")
                    .accept("application/json")
                    .body(SdkBytes.fromUtf8String(requestBody))
                    .build();

            InvokeModelResponse response = bedrockClient.invokeModel(request);
            String responseJson = response.body().asUtf8String();

            // Parse the Nova Micro response envelope
            JsonNode root = objectMapper.readTree(responseJson);
            String content = root.path("output").path("message").path("content")
                    .get(0).path("text").asText();

            // Parse the model's structured JSON payload
            JsonNode payload = objectMapper.readTree(content);
            List<String> rawCategories = objectMapper.convertValue(
                    payload.get("categories"), new TypeReference<>() {});
            String blurb = payload.path("blurb").asText("Here are some great destinations for you.");

            List<Category> categories = rawCategories.stream()
                    .map(c -> {
                        try { return Category.valueOf(c); }
                        catch (IllegalArgumentException e) { return null; }
                    })
                    .filter(c -> c != null)
                    .collect(Collectors.toList());

            if (categories.isEmpty()) {
                log.warn("Bedrock returned no valid categories for query: {}", userQuery);
                return allDestinationsNoBlurb();
            }

            List<Destination> destinations = destinationRepository.findByCategoryIn(categories);
            return destinations.stream()
                    .map(d -> new RecommendationResult(d, blurb))
                    .collect(Collectors.toList());

        } catch (Exception e) {
            log.warn("Bedrock recommendation failed ({}); falling back to all destinations.", e.getMessage());
            return allDestinationsNoBlurb();
        }
    }

    private List<RecommendationResult> allDestinationsNoBlurb() {
        return destinationRepository.findAll().stream()
                .map(d -> new RecommendationResult(d, null))
                .collect(Collectors.toList());
    }
}
