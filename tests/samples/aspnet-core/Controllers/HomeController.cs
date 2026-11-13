using Microsoft.AspNetCore.Mvc;

namespace HelpDesk.TicketApi.Controllers
{
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }

        public IActionResult About()
        {
            return View("About", new { Version = "1" });
        }

        public IActionResult Missing()
        {
            return View("NotThere");
        }

        public IActionResult Fail() => View("Error");
    }
}
