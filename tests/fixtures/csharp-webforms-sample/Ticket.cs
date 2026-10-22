namespace HelpDesk.Models
{
    /// <summary>A help-desk ticket row mapped from HelpDesk.Tickets.</summary>
    public class Ticket
    {
        public int TicketId { get; set; }
        public string CustomerName { get; set; }
        public string Subject { get; set; }
        public string Status { get; set; }
    }
}
