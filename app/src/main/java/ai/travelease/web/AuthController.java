package ai.travelease.web;

import ai.travelease.service.UserService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
public class AuthController {

    private final UserService userService;

    public AuthController(UserService userService) {
        this.userService = userService;
    }

    // ─── Login ──────────────────────────────────────────────────────────────

    @GetMapping("/login")
    public String loginPage(@RequestParam(required = false) String error, Model model) {
        if (error != null) {
            model.addAttribute("loginError", "Invalid email or password.");
        }
        return "login";
    }

    // ─── Registration ────────────────────────────────────────────────────────

    @GetMapping("/register")
    public String registerPage() {
        return "register";
    }

    @PostMapping("/register")
    public String register(@RequestParam String name,
                           @RequestParam String email,
                           @RequestParam String password,
                           Model model) {
        try {
            userService.registerUser(name, email, password);
            return "redirect:/login?registered=true";
        } catch (IllegalArgumentException e) {
            model.addAttribute("registerError", e.getMessage());
            return "register";
        }
    }
}
