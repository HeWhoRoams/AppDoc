using System;
using System.Web.Http;

namespace HelpDesk.Api
{
    public class TicketService
    {
        [HttpGet("/api/tickets")]
        public string ListTickets()
        {
            return "[]";
        }

        [HttpPost("/api/tickets")]
        public string CreateTicket()
        {
            return "created";
        }
    }
}
