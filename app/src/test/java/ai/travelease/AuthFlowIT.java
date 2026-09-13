package ai.travelease;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.MediaType;
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Integration test covering the full register → login → view bookings flow.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
                properties = {"app.recommendation.enabled=false"})
@AutoConfigureMockMvc
@Testcontainers
class AuthFlowIT {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16-alpine")
                    .withDatabaseName("travelease_auth_test")
                    .withUsername("travelease")
                    .withPassword("testpassword");

    @Autowired private MockMvc mockMvc;

    @Test
    void registerPage_returnsOk() throws Exception {
        mockMvc.perform(get("/register"))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Create Account")));
    }

    @Test
    void loginPage_returnsOk() throws Exception {
        mockMvc.perform(get("/login"))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Welcome Back")));
    }

    @Test
    void registerThenLogin_happyPath() throws Exception {
        // Step 1: Register a new user
        mockMvc.perform(post("/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("name", "Test User")
                .param("email", "testflow@example.com")
                .param("password", "securepassword123"))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrl("/login?registered=true"));

        // Step 2: Attempt to login with registered credentials
        mockMvc.perform(post("/login")
                .with(csrf())
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("username", "testflow@example.com")
                .param("password", "securepassword123"))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrl("/"));
    }

    @Test
    void registerWithDuplicateEmail_showsError() throws Exception {
        // Register first
        mockMvc.perform(post("/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("name", "Alice")
                .param("email", "duplicate@example.com")
                .param("password", "password1"))
                .andExpect(status().is3xxRedirection());

        // Register again with same email
        mockMvc.perform(post("/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("name", "Alice2")
                .param("email", "duplicate@example.com")
                .param("password", "password2"))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("already registered")));
    }

    @Test
    void myBookings_requiresAuthentication_redirectsToLogin() throws Exception {
        mockMvc.perform(get("/my-bookings"))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrlPattern("**/login"));
    }
}
