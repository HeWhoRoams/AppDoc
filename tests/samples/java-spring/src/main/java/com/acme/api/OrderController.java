package com.acme.api;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping(
        value = "/api/orders")
public class OrderController {

    // @GetMapping("/commented-out")
    /* @DeleteMapping("/dead-block") */

    @RequestMapping(
            value = {"/search", "/find"},
            method = RequestMethod.GET)
    public String search() {
        return "x";
    }

    @PreAuthorize("hasAnyRole('ADMIN','CLERK')")
    @PostMapping(path = "/{id}/cancel")
    public ResponseEntity<String> cancel(@PathVariable long id) {
        if (id < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Order id must be positive");
        }
        return ResponseEntity.status(HttpStatus.CONFLICT).body("Order already shipped");
    }

    @Scheduled(cron = "0 0 * * * *")
    public void nightlySweep() {
        String sql = "SELECT id FROM orders "
                + "WHERE status = 'STALE'";
    }

    @GetMapping("/wild/*")
    public String wildcard() {
        return "w";
    }
}
