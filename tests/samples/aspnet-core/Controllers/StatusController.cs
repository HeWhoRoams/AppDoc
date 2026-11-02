using System.Net;
using Microsoft.AspNetCore.Mvc;

namespace HelpDesk.TicketApi.Controllers
{
    [ApiController]
    public class StatusController : ControllerBase
    {
        private readonly IHttpClientFactory _httpClientFactory;

        public StatusController(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        /// <summary>
        /// Report service status by pinging the downstream status service.
        /// </summary>
        [HttpGet("/api/status")]
        public async Task<IActionResult> Status()
        {
            var client = _httpClientFactory.CreateClient("StatusClient");
            var response = await client.GetAsync("/health");
            return Ok(new
            {
                status = response.StatusCode == HttpStatusCode.OK ? "healthy" : "degraded",
                checkedAt = DateTime.UtcNow
            });
        }
    }
}
