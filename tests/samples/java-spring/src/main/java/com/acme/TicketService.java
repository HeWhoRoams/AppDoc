package com.acme;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

/**
 * Ticket business logic. Backed by the JPA repository; also syncs ticket
 * status to the external ITSM system (outbound HTTP boundary).
 */
@Service
public class TicketService {

    private final TicketRepository repository;
    private final RestTemplate restTemplate = new RestTemplate();

    // Base URL of the external ITSM system (see application.yml).
    @Value("${itsm.base-url}")
    private String itsmBaseUrl;

    public TicketService(TicketRepository repository) {
        this.repository = repository;
    }

    public List<Ticket> findAll(String status) {
        if (status != null && !status.isBlank()) {
            return repository.findByStatus(status);
        }
        return repository.findAll();
    }

    public Ticket findById(long id) {
        return repository.findById(id).orElseThrow(() -> new IllegalStateException("ticket not found: " + id));
    }

    public Ticket create(Ticket ticket) {
        Ticket saved = repository.save(ticket);
        // Outbound: push the new ticket to the external ITSM system.
        try {
            restTemplate.postForObject(itsmBaseUrl + "/intake/tickets", saved, Ticket.class);
        } catch (Exception ignored) {
            // Non-fatal: ITSM notification failures must not block ticket creation.
        }
        return saved;
    }

    public Ticket update(long id, Ticket incoming) {
        Ticket existing = findById(id);
        existing.setSubject(incoming.getSubject());
        existing.setStatus(incoming.getStatus());
        existing.setPriority(incoming.getPriority());
        existing.setCustomerName(incoming.getCustomerName());
        return repository.save(existing);
    }

    public void delete(long id) {
        repository.deleteById(id);
    }
}
