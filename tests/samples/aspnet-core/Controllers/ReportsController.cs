using HelpDesk.TicketApi.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HelpDesk.TicketApi.Controllers
{
    // BannerAttribute is not defined in the Target: three uses make it a guard candidate (or a layout attribute).
    [Banner("Reports")]
    [StaffGate]
    [Authorize(Roles = Rolenames.Support)]
    public class ReportsController : Controller
    {
        [Banner("Daily")]
        public IActionResult Daily() => View();

        [Banner("Weekly")]
        public IActionResult Weekly()
        {
            return Allowed(Rolenames.Support, Rolenames.Supervisor) ? View() : Forbid();
        }

        private bool Allowed(string a, string b) => User.IsInRole(a) || User.IsInRole(b);
    }
}
