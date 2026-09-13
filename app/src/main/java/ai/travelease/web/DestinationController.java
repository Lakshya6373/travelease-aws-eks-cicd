package ai.travelease.web;

import ai.travelease.domain.Destination;
import ai.travelease.service.DestinationService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Controller
@RequestMapping("/destinations")
public class DestinationController {

    private final DestinationService destinationService;

    public DestinationController(DestinationService destinationService) {
        this.destinationService = destinationService;
    }

    @GetMapping
    public String list(Model model) {
        model.addAttribute("destinations", destinationService.findAll());
        return "destinations";
    }

    @GetMapping("/{id}")
    public String detail(@PathVariable Long id, Model model) {
        Destination destination = destinationService.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Destination not found"));
        model.addAttribute("destination", destination);
        return "destination-detail";
    }
}
