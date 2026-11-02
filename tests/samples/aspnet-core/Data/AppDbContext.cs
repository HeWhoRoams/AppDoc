using Dapper;
using Microsoft.EntityFrameworkCore;

namespace HelpDesk.TicketApi.Data
{
    public class AppDbContext : DbContext
    {
        public DbSet<Ticket> Tickets { get; set; }
        public DbSet<Comment> Comments { get; set; }

        public List<Ticket> Recent()
        {
            return Tickets.FromSqlRaw("SELECT * FROM dbo.Tickets WHERE Status = 'Open'").ToList();
        }

        public int Purge()
        {
            return Database.ExecuteSqlRaw("DELETE FROM dbo.AuditLog WHERE CreatedAt < @p0");
        }

        public IEnumerable<Comment> Comments_For(System.Data.IDbConnection conn, int id)
        {
            conn.Execute("dbo.usp_TouchTicket", new { id }, commandType: System.Data.CommandType.StoredProcedure);
            return conn.Query<Comment>("SELECT Id, Body FROM Comments WHERE TicketId = @id", new { id });
        }
    }
}
