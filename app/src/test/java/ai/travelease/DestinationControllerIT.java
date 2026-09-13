package ai.travelease;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Integration test: spins up a real PostgreSQL container via Testcontainers,
 * loads the full Spring context, seeds data via Flyway, and asserts the
 * destinations endpoints return correct HTTP status and content.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
                properties = {"app.recommendation.enabled=false"})
@AutoConfigureMockMvc
@Testcontainers
class DestinationControllerIT {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16-alpine")
                    .withDatabaseName("travelease_test")
                    .withUsername("travelease")
                    .withPassword("testpassword");

    @Autowired private MockMvc mockMvc;

    @Test
    void getDestinations_returnsOkAndHtmlContent() throws Exception {
        mockMvc.perform(get("/destinations").accept(MediaType.TEXT_HTML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_HTML))
                .andExpect(content().string(containsString("All Destinations")));
    }

    @Test
    void getDestinationById_existingId_returnsDetailPage() throws Exception {
        // Seed data from V2 migration means id=1 (Manali) exists
        mockMvc.perform(get("/destinations/1").accept(MediaType.TEXT_HTML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Manali")));
    }

    @Test
    void getDestinationById_nonExistentId_returns404() throws Exception {
        mockMvc.perform(get("/destinations/999999").accept(MediaType.TEXT_HTML))
                .andExpect(status().isNotFound());
    }

    @Test
    void homePage_returnsOkAndFeaturedSection() throws Exception {
        mockMvc.perform(get("/").accept(MediaType.TEXT_HTML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Featured Destinations")));
    }
}
