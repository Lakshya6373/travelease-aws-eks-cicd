package ai.travelease;

import ai.travelease.domain.Booking;
import ai.travelease.domain.Category;
import ai.travelease.domain.Destination;
import ai.travelease.domain.User;
import ai.travelease.repository.BookingRepository;
import ai.travelease.repository.DestinationRepository;
import ai.travelease.repository.UserRepository;
import ai.travelease.service.BookingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BookingServiceTest {

    @Mock private BookingRepository bookingRepository;
    @Mock private UserRepository userRepository;
    @Mock private DestinationRepository destinationRepository;

    private BookingService bookingService;

    private User testUser;
    private Destination testDestination;

    @BeforeEach
    void setUp() {
        bookingService = new BookingService(bookingRepository, userRepository, destinationRepository);

        testUser = new User("Alice", "alice@example.com", "hashedPassword", User.Role.USER);
        testDestination = new Destination("Manali", "India", "Mountains",
                new BigDecimal("89.00"), null, Category.MOUNTAIN);
    }

    @Test
    void createBooking_successPath_savesBooking() {
        // Given
        when(userRepository.findById(1L)).thenReturn(Optional.of(testUser));
        when(destinationRepository.findById(1L)).thenReturn(Optional.of(testDestination));

        Booking savedBooking = new Booking(testUser, testDestination,
                LocalDate.of(2026, 11, 1), LocalDate.of(2026, 11, 7), 2);
        when(bookingRepository.save(any(Booking.class))).thenReturn(savedBooking);

        // When
        Booking result = bookingService.createBooking(1L, 1L,
                LocalDate.of(2026, 11, 1), LocalDate.of(2026, 11, 7), 2);

        // Then
        assertThat(result.getStatus()).isEqualTo(Booking.Status.PENDING);
        assertThat(result.getGuests()).isEqualTo(2);
        verify(bookingRepository).save(any(Booking.class));
    }

    @Test
    void createBooking_throwsIllegalArgument_whenCheckOutNotAfterCheckIn() {
        LocalDate checkIn  = LocalDate.of(2026, 11, 7);
        LocalDate checkOut = LocalDate.of(2026, 11, 1); // before check-in

        assertThatThrownBy(() -> bookingService.createBooking(1L, 1L, checkIn, checkOut, 1))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Check-out date must be after check-in date");

        verify(bookingRepository, never()).save(any());
    }

    @Test
    void createBooking_throwsIllegalArgument_whenCheckOutEqualsCheckIn() {
        LocalDate same = LocalDate.of(2026, 11, 5);

        assertThatThrownBy(() -> bookingService.createBooking(1L, 1L, same, same, 1))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createBooking_throwsIllegalArgument_whenUserNotFound() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> bookingService.createBooking(99L, 1L,
                LocalDate.now(), LocalDate.now().plusDays(3), 1))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("User not found");
    }
}
