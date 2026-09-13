package ai.travelease.domain;

import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity
@Table(name = "destinations", indexes = {
        @Index(name = "idx_destination_category", columnList = "category")
})
public class Destination {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String country;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "price_per_night", nullable = false, precision = 10, scale = 2)
    private BigDecimal pricePerNight;

    @Column(name = "image_url")
    private String imageUrl;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Category category;

    // ─── Constructors ───────────────────────────────────────────────────────

    public Destination() {}

    public Destination(String name, String country, String description,
                       BigDecimal pricePerNight, String imageUrl, Category category) {
        this.name = name;
        this.country = country;
        this.description = description;
        this.pricePerNight = pricePerNight;
        this.imageUrl = imageUrl;
        this.category = category;
    }

    // ─── Getters & Setters ──────────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getCountry() { return country; }
    public void setCountry(String country) { this.country = country; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public BigDecimal getPricePerNight() { return pricePerNight; }
    public void setPricePerNight(BigDecimal pricePerNight) { this.pricePerNight = pricePerNight; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public Category getCategory() { return category; }
    public void setCategory(Category category) { this.category = category; }
}
