package ai.travelease.web;

import ai.travelease.domain.User;
import ai.travelease.service.BookingService;
import ai.travelease.service.UserService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

import java.time.LocalDate;

@Controller
public class BookingController {

    private final BookingService bookingService;
    private final UserService userService;

    public BookingController(BookingService bookingService, UserService userService) {
        this.bookingService = bookingService;
        this.userService = userService;
    }

    @GetMapping("/my-bookings")
    public String myBookings(@AuthenticationPrincipal UserDetails userDetails, Model model) {
        User user = userService.findByEmail(userDetails.getUsername());
        model.addAttribute("bookings", bookingService.findBookingsByUser(user.getId()));
        return "my-bookings";
    }

    @PostMapping("/bookings")
    public String createBooking(@AuthenticationPrincipal UserDetails userDetails,
                                @RequestParam Long destinationId,
                                @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate checkIn,
                                @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate checkOut,
                                @RequestParam int guests,
                                Model model) {
        try {
            User user = userService.findByEmail(userDetails.getUsername());
            bookingService.createBooking(user.getId(), destinationId, checkIn, checkOut, guests);
            return "redirect:/my-bookings?success=true";
        } catch (IllegalArgumentException e) {
            model.addAttribute("bookingError", e.getMessage());
            return "redirect:/destinations/" + destinationId + "?bookingError=true";
        }
    }
}
