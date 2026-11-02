package com.acme;

import java.util.List;

import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST controller for the ticket resource. The verb-mapping annotations
 * (@GetMapping / @PostMapping / @PutMapping / @DeleteMapping) are the endpoint
 * surface the AppDoc generic extractor detects (Spring Java path).
 */
@RestController
public class TicketsController {

    private final TicketService service;

    public TicketsController(TicketService service) {
        this.service = service;
    }

    // GET /api/tickets — list all tickets, optionally filtered by status.
    @GetMapping("/api/tickets")
    public List<Ticket> list(@RequestParam(required = false) String status) {
        return service.findAll(status);
    }

    // GET /api/tickets/{id} — fetch a single ticket by id.
    @GetMapping("/api/tickets/{id}")
    public Ticket get(@PathVariable long id) {
        return service.findById(id);
    }

    // POST /api/tickets — create a new ticket from the JSON body.
    @PostMapping("/api/tickets")
    public Ticket create(@RequestBody Ticket ticket) {
        return service.create(ticket);
    }

    // PUT /api/tickets/{id} — replace a ticket.
    @PutMapping("/api/tickets/{id}")
    public Ticket update(@PathVariable long id, @RequestBody Ticket ticket) {
        return service.update(id, ticket);
    }

    // DELETE /api/tickets/{id} — delete a ticket.
    @DeleteMapping("/api/tickets/{id}")
    public void delete(@PathVariable long id) {
        service.delete(id);
    }
}
