package ai.travelease.dto;

import ai.travelease.domain.Destination;

public class RecommendationResult {
    private final Destination destination;
    private final String aiBlurb;

    public RecommendationResult(Destination destination, String aiBlurb) {
        this.destination = destination;
        this.aiBlurb = aiBlurb;
    }

    public Destination getDestination() { return destination; }
    public String getAiBlurb() { return aiBlurb; }
    public boolean hasBlurb() { return aiBlurb != null && !aiBlurb.isBlank(); }
}
