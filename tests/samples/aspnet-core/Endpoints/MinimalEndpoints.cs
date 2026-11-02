using Microsoft.AspNetCore.Builder;

namespace HelpDesk.TicketApi.Endpoints
{
    public static class MinimalEndpoints
    {
        public static void Map(WebApplication app)
        {
            app.MapGet("/ping", () => "pong");

            var api = app.MapGroup("/api/reports").RequireAuthorization("ReportsPolicy");
            api.MapGet("/daily", ReportHandlers.Daily);
            api.MapPost("/{id}/export", (int id) =>
            {
                if (id < 0) return Results.BadRequest("Report id is invalid.");
                return Results.Ok();
            });
            app.MapDelete("/api/cache", () => Results.NoContent()).RequireAuthorization();
        }
    }
}
