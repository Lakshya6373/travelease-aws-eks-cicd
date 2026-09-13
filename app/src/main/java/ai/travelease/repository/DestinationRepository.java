package ai.travelease.repository;

import ai.travelease.domain.Category;
import ai.travelease.domain.Destination;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DestinationRepository extends JpaRepository<Destination, Long> {

    List<Destination> findByCategoryIn(List<Category> categories);
}
