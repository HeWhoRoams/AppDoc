using System.Data;
using System.Data.SqlClient;
using HelpDesk.TicketApi.Models;
using Microsoft.Extensions.Configuration;

namespace HelpDesk.TicketApi.Data
{
    /// <summary>
    /// ADO.NET data access for the Tickets table. The connection string comes
    /// from appsettings.json (connectionStrings:Default) and is never hardcoded.
    /// </summary>
    public class TicketRepository
    {
        private readonly IConfiguration _config;

        public TicketRepository(IConfiguration config)
        {
            _config = config;
        }

        private string ConnectionString => _config.GetConnectionString("Default");

        public List<Ticket> GetAll()
        {
            var tickets = new List<Ticket>();
            using var connection = new SqlConnection(ConnectionString);
            using var command = new SqlCommand("SELECT Id, Subject, Description, Status, CreatedAt FROM Tickets ORDER BY CreatedAt DESC", connection);
            connection.Open();
            using var reader = command.ExecuteReader();
            while (reader.Read())
            {
                tickets.Add(MapRow(reader));
            }
            return tickets;
        }

        public Ticket? GetById(int id)
        {
            using var connection = new SqlConnection(ConnectionString);
            using var command = new SqlCommand("SELECT Id, Subject, Description, Status, CreatedAt FROM Tickets WHERE Id = @Id", connection);
            command.Parameters.AddWithValue("@Id", id);
            connection.Open();
            using var reader = command.ExecuteReader();
            return reader.Read() ? MapRow(reader) : null;
        }

        public int Add(Ticket ticket)
        {
            using var connection = new SqlConnection(ConnectionString);
            using var command = new SqlCommand(
                "INSERT INTO Tickets (Subject, Description, Status, CreatedAt) VALUES (@Subject, @Description, @Status, @CreatedAt); SELECT CAST(SCOPE_IDENTITY() AS INT)",
                connection);
            command.Parameters.AddWithValue("@Subject", ticket.Subject);
            command.Parameters.AddWithValue("@Description", (object?)ticket.Description ?? DBNull.Value);
            command.Parameters.AddWithValue("@Status", ticket.Status);
            command.Parameters.AddWithValue("@CreatedAt", ticket.CreatedAt);
            connection.Open();
            return (int)command.ExecuteScalar();
        }

        private static Ticket MapRow(SqlDataReader reader)
        {
            return new Ticket
            {
                Id = reader.GetInt32(0),
                Subject = reader.GetString(1),
                Description = reader.IsDBNull(2) ? null : reader.GetString(2),
                Status = reader.GetString(3),
                CreatedAt = reader.GetDateTime(4)
            };
        }
    }
}
