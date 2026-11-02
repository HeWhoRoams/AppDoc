using System.Diagnostics;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;

namespace HelpDesk.TicketApi.Services
{
    public class NotificationService
    {
        private readonly IHttpClientFactory _factory;
        private readonly string _smtpPassword = "fakepass-core-9911";

        public NotificationService(IHttpClientFactory factory, IConfiguration config)
        {
            _factory = factory;
            var cs = config.GetConnectionString("Audit");
        }

        public async Task Notify(string to)
        {
            var client = _factory.CreateClient("PagerClient");
            await client.PostAsync("https://pager.fixture.internal/v1/notify?apikey=fakepass-query", null);
            using var smtp = new SmtpClient("smtp.fixture.internal");
            File.WriteAllText("/var/log/helpdesk/notify.log", to);
            Process.Start("/usr/bin/logger");
        }
    }
}
