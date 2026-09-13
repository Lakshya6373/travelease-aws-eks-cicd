package ai.travelease.service;

import ai.travelease.domain.Booking;
import ai.travelease.domain.Destination;
import ai.travelease.domain.User;
import ai.travelease.repository.BookingRepository;
import ai.travelease.repository.DestinationRepository;
import ai.travelease.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
public class BookingService {

    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final DestinationRepository destinationRepository;

    public BookingService(BookingRepository bookingRepository,
                          UserRepository userRepository,
                          DestinationRepository destinationRepository) {
        this.bookingRepository = bookingRepository;
        this.userRepository = userRepository;
        this.destinationRepository = destinationRepository;
    }

    /**
     * Creates a new booking for the given user.
     * Validates that checkOut is strictly after checkIn.
     */
    @Transactional
    public Booking createBooking(Long userId, Long destinationId,
                                 LocalDate checkIn, LocalDate checkOut, int guests) {
        if (!checkOut.isAfter(checkIn)) {
            throw new IllegalArgumentException("Check-out date must be after check-in date.");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        Destination destination = destinationRepository.findById(destinationId)
                .orElseThrow(() -> new IllegalArgumentException("Destination not found: " + destinationId));

        Booking booking = new Booking(user, destination, checkIn, checkOut, guests);
        return bookingRepository.save(booking);
    }

    /**
     * Retrieves all bookings for the given user, ordered by check-in date.
     */
    @Transactional(readOnly = true)
    public List<Booking> findBookingsByUser(Long userId) {
        return bookingRepository.findByUserId(userId);
    }
}
