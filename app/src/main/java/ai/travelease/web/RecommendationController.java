package ai.travelease.web;

import ai.travelease.dto.RecommendationRequest;
import ai.travelease.service.RecommendationService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/recommend")
public class RecommendationController {

    private final RecommendationService recommendationService;

    public RecommendationController(RecommendationService recommendationService) {
        this.recommendationService = recommendationService;
    }

    /** Renders the recommendation search page with no results (initial load). */
    @GetMapping
    public String recommendPage(Model model) {
        model.addAttribute("results", null);
        model.addAttribute("query", null);
        return "recommend";
    }

    /** Handles the HTMX/form POST and returns the results fragment. */
    @PostMapping
    public String recommend(RecommendationRequest request, Model model) {
        model.addAttribute("results", recommendationService.recommend(request.getQuery()));
        model.addAttribute("query", request.getQuery());
        return "fragments/recommendation-results :: results";
    }
}
