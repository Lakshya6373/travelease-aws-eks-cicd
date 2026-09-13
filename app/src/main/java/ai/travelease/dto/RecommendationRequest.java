package ai.travelease.dto;

public class RecommendationRequest {
    private String query;

    public RecommendationRequest() {}
    public RecommendationRequest(String query) { this.query = query; }

    public String getQuery() { return query; }
    public void setQuery(String query) { this.query = query; }
}
