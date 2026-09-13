package ai.travelease.service;

import ai.travelease.domain.Destination;
import ai.travelease.repository.DestinationRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class DestinationService {

    private final DestinationRepository destinationRepository;

    public DestinationService(DestinationRepository destinationRepository) {
        this.destinationRepository = destinationRepository;
    }

    public List<Destination> findAll() {
        return destinationRepository.findAll();
    }

    public Optional<Destination> findById(Long id) {
        return destinationRepository.findById(id);
    }
}
