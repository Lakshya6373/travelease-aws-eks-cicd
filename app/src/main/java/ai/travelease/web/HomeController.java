package ai.travelease.web;

import ai.travelease.service.DestinationService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    private final DestinationService destinationService;

    public HomeController(DestinationService destinationService) {
        this.destinationService = destinationService;
    }

    @GetMapping("/")
    public String home(Model model) {
        // Show up to 6 featured destinations on the homepage
        var all = destinationService.findAll();
        model.addAttribute("featured", all.stream().limit(6).toList());
        return "home";
    }
}
