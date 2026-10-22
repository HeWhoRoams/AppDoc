using System.ComponentModel.DataAnnotations;

namespace HelpDesk.TicketApi.Models
{
    public class Ticket
    {
        public int Id { get; set; }

        [Required]
        public string Subject { get; set; } = "";

        public string? Description { get; set; }

        public string Status { get; set; } = "Open";

        public DateTime CreatedAt { get; set; }
    }
}
