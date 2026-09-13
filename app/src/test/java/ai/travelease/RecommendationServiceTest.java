package ai.travelease;

import ai.travelease.domain.Category;
import ai.travelease.domain.Destination;
import ai.travelease.dto.RecommendationResult;
import ai.travelease.repository.DestinationRepository;
import ai.travelease.service.RecommendationService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelRequest;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelResponse;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RecommendationServiceTest {

    @Mock private BedrockRuntimeClient bedrockClient;
    @Mock private DestinationRepository destinationRepository;

    private RecommendationService service;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        service = new RecommendationService(bedrockClient, destinationRepository, objectMapper);
        ReflectionTestUtils.setField(service, "recommendationEnabled", true);
        ReflectionTestUtils.setField(service, "modelId", "amazon.nova-micro-v1:0");
    }

    @Test
    void recommend_parsesBedrockJsonResponse_andQueriesCategories() throws Exception {
        // Given: Bedrock returns categories MOUNTAIN and ADVENTURE
        String bedrockPayload = """
            {"output":{"message":{"content":[{"text":"{\\"categories\\":[\\"MOUNTAIN\\",\\"ADVENTURE\\"],\\"blurb\\":\\"Perfect for thrill-seekers in the hills!\\"}"}]}}}
            """;
        InvokeModelResponse mockResponse = InvokeModelResponse.builder()
                .body(SdkBytes.fromUtf8String(bedrockPayload))
                .build();
        when(bedrockClient.invokeModel(any(InvokeModelRequest.class))).thenReturn(mockResponse);

        Destination manali = new Destination("Manali", "India", "Himalayan hill station",
                new BigDecimal("89.00"), "http://img.test/manali.jpg", Category.MOUNTAIN);
        Destination queenstown = new Destination("Queenstown", "New Zealand", "Adventure capital",
                new BigDecimal("175.00"), "http://img.test/qtown.jpg", Category.ADVENTURE);

        when(destinationRepository.findByCategoryIn(List.of(Category.MOUNTAIN, Category.ADVENTURE)))
                .thenReturn(List.of(manali, queenstown));

        // When
        List<RecommendationResult> results = service.recommend("I want mountains and adventure");

        // Then
        assertThat(results).hasSize(2);
        assertThat(results.get(0).getDestination().getName()).isEqualTo("Manali");
        assertThat(results.get(0).getAiBlurb()).isEqualTo("Perfect for thrill-seekers in the hills!");
        assertThat(results.get(0).hasBlurb()).isTrue();

        ArgumentCaptor<InvokeModelRequest> requestCaptor = ArgumentCaptor.forClass(InvokeModelRequest.class);
        verify(bedrockClient).invokeModel(requestCaptor.capture());
        assertThat(requestCaptor.getValue().modelId()).isEqualTo("amazon.nova-micro-v1:0");
    }

    @Test
    void recommend_fallsBackToAllDestinations_whenBedrockThrows() {
        // Given: Bedrock call fails
        when(bedrockClient.invokeModel(any(InvokeModelRequest.class)))
                .thenThrow(new RuntimeException("Bedrock throttled"));

        Destination fallback = new Destination("Goa", "India", "Beach resort",
                new BigDecimal("65.00"), null, Category.BEACH);
        when(destinationRepository.findAll()).thenReturn(List.of(fallback));

        // When
        List<RecommendationResult> results = service.recommend("any query");

        // Then: returns all destinations with no blurb
        assertThat(results).hasSize(1);
        assertThat(results.get(0).hasBlurb()).isFalse();
        verify(destinationRepository).findAll();
        verify(destinationRepository, never()).findByCategoryIn(any());
    }

    @Test
    void recommend_returnsAllDestinations_whenFeatureDisabled() {
        // Given: recommendation disabled
        ReflectionTestUtils.setField(service, "recommendationEnabled", false);
        Destination dest = new Destination("Bali", "Indonesia", "Island paradise",
                new BigDecimal("120.00"), null, Category.HONEYMOON);
        when(destinationRepository.findAll()).thenReturn(List.of(dest));

        // When
        List<RecommendationResult> results = service.recommend("any query");

        // Then: Bedrock is never called
        assertThat(results).hasSize(1);
        verifyNoInteractions(bedrockClient);
    }

    @Test
    void recommend_handlesUnknownCategories_gracefully() throws Exception {
        // Given: Bedrock returns an invalid category name
        String bedrockPayload = """
            {"output":{"message":{"content":[{"text":"{\\"categories\\":[\\"UNKNOWN_CAT\\"],\\"blurb\\":\\"Unknown.\\"}"}]}}}
            """;
        InvokeModelResponse mockResponse = InvokeModelResponse.builder()
                .body(SdkBytes.fromUtf8String(bedrockPayload))
                .build();
        when(bedrockClient.invokeModel(any(InvokeModelRequest.class))).thenReturn(mockResponse);

        Destination fallback = new Destination("Paris", "France", "City of light",
                new BigDecimal("220.00"), null, Category.CITY);
        when(destinationRepository.findAll()).thenReturn(List.of(fallback));

        // When: invalid category → fallback to all destinations
        List<RecommendationResult> results = service.recommend("something weird");

        assertThat(results).hasSize(1);
        verify(destinationRepository).findAll();
    }
}
