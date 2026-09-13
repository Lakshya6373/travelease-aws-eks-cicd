package ai.travelease.domain;

import jakarta.persistence.*;
import java.time.LocalDate;

@Entity
@Table(name = "bookings")
public class Booking {

    public enum Status {
        PENDING, CONFIRMED, CANCELLED
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "destination_id", nullable = false)
    private Destination destination;

    @Column(name = "check_in", nullable = false)
    private LocalDate checkIn;

    @Column(name = "check_out", nullable = false)
    private LocalDate checkOut;

    @Column(nullable = false)
    private int guests;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status = Status.PENDING;

    // ─── Constructors ───────────────────────────────────────────────────────

    public Booking() {}

    public Booking(User user, Destination destination, LocalDate checkIn,
                   LocalDate checkOut, int guests) {
        this.user = user;
        this.destination = destination;
        this.checkIn = checkIn;
        this.checkOut = checkOut;
        this.guests = guests;
        this.status = Status.PENDING;
    }

    // ─── Getters & Setters ──────────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public Destination getDestination() { return destination; }
    public void setDestination(Destination destination) { this.destination = destination; }

    public LocalDate getCheckIn() { return checkIn; }
    public void setCheckIn(LocalDate checkIn) { this.checkIn = checkIn; }

    public LocalDate getCheckOut() { return checkOut; }
    public void setCheckOut(LocalDate checkOut) { this.checkOut = checkOut; }

    public int getGuests() { return guests; }
    public void setGuests(int guests) { this.guests = guests; }

    public Status getStatus() { return status; }
    public void setStatus(Status status) { this.status = status; }
}
