using Microsoft.EntityFrameworkCore;

namespace HelpDesk.TicketApi.Data
{
    public class TicketQueries
    {
        private readonly AppDbContext _db;

        public async Task<List<Ticket>> Open() =>
            await _db.Tickets.Where(t => t.Status == "Open").ToListAsync();

        public async Task<Ticket> First() => await _db.Tickets.FirstOrDefaultAsync();
    }
}
