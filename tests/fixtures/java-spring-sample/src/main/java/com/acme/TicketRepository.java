package com.acme;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

/**
 * JPA repository for the Ticket entity.
 */
public interface TicketRepository extends JpaRepository<Ticket, Long> {

    List<Ticket> findByStatus(String status);
}
