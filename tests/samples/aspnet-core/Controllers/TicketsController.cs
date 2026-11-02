using System.ComponentModel.DataAnnotations;
using HelpDesk.TicketApi.Data;
using HelpDesk.TicketApi.Models;
using Microsoft.AspNetCore.Mvc;

namespace HelpDesk.TicketApi.Controllers
{
    [ApiController]
    public class TicketsController : ControllerBase
    {
        private readonly TicketRepository _repo;

        public TicketsController(TicketRepository repo)
        {
            _repo = repo;
        }

        /// <summary>
        /// List all tickets, most recent first.
        /// </summary>
        [HttpGet("/api/tickets")]
        public IActionResult List()
        {
            return Ok(_repo.GetAll());
        }

        /// <summary>
        /// Get a single ticket by its id.
        /// </summary>
        [HttpGet("/api/tickets/{id}")]
        public IActionResult GetById(int id)
        {
            var ticket = _repo.GetById(id);
            return ticket is null ? NotFound() : Ok(ticket);
        }

        /// <summary>
        /// Create a new ticket.
        /// </summary>
        [HttpPost("/api/tickets")]
        public IActionResult Create([FromBody] Ticket ticket)
        {
            if (ticket is null || string.IsNullOrWhiteSpace(ticket.Subject))
            {
                return BadRequest(new { error = "Subject is required." });
            }

            _repo.Add(ticket);
            return Ok(ticket);
        }
    }
}
