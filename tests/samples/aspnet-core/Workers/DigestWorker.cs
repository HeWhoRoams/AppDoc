using Microsoft.Extensions.Hosting;
using Hangfire;

namespace HelpDesk.TicketApi.Workers
{
    public class DigestWorker : BackgroundService
    {
        private readonly IConfiguration _configuration;

        public DigestWorker(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var interval = _configuration.GetValue<int>("Digest:IntervalMinutes");
            var smtp = _configuration["Smtp:Host"];
            var key = _configuration["Smtp:ApiKey"];
            var section = _configuration.GetSection("Digest");
            var env = Environment.GetEnvironmentVariable("DIGEST_TOKEN");
        }
    }

    public class CleanupService : IHostedService
    {
        public Task StartAsync(CancellationToken cancellationToken) => Task.CompletedTask;
        public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
    }

    public static class JobSetup
    {
        public static void Register(IServiceCollection services)
        {
            services.AddHostedService<DigestWorker>();
            RecurringJob.AddOrUpdate("close-stale", () => Console.WriteLine("sweep"), "0 */6 * * *");
            RecurringJob.AddOrUpdate<ITicketService>("daily-digest", s => s.SendDigest(), Cron.Daily);
        }
    }

    public class QueueWorker(ILogger<QueueWorker> logger, IOptions<QueueOptions> options) : BackgroundService
    {
        protected override Task ExecuteAsync(CancellationToken stoppingToken) => Task.CompletedTask;
    }

    public abstract class WorkerBase : BackgroundService
    {
    }
}
