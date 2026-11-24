using Microsoft.AspNetCore.Http;

namespace HelpDesk.TicketApi.Services
{
    public class PagerClient
    {
        private readonly HttpClient _http;

        public async Task<string> Status() => await _http.GetStringAsync("https://status.fixture.internal/v1/health?token=x");

        public async Task Ping(HttpRequestMessage req) => await _http.SendAsync(req);
    }
}
