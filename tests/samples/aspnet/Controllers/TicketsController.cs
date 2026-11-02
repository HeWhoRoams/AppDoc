using System;
using System.Diagnostics;
using System.IO;
using System.Net.Mail;
using System.Web.Mvc;
using HelpDesk.Models;

namespace HelpDesk.Controllers
{
    [Authorize(Roles = "Admin,Support")]
    public class TicketsController : Controller
    {
        private HelpDeskContext db = new HelpDeskContext();
        private const string apiKey = "fakepass-apikey-9988";

        public ActionResult Index()
        {
            return View(db.Tickets);
        }

        [AllowAnonymous]
        [HttpGet]
        [Route("tickets/{id:int}")]
        public ActionResult Details(int id)
        {
            return View();
        }

        [HttpPost]
        public ActionResult Create(Ticket ticket)
        {
            if (!ModelState.IsValid)
            {
                ModelState.AddModelError("Subject", "Subject is required.");
                return View(ticket);
            }
            if (!User.IsInRole("Supervisor"))
            {
                return new HttpUnauthorizedResult();
            }
            var smtp = new SmtpClient("mail.fixture.internal");
            smtp.Send("noreply@fixture.internal", "desk@fixture.internal", "New ticket", "body");
            var template = File.ReadAllText(Server.MapPath("~/App_Data/ticket-template.txt"));
            Process.Start("C:\\tools\\archive.exe");
            // ModelState.AddModelError("", "This commented-out message must not appear.");
            return RedirectToAction("Index");
        }

        [NonAction]
        public ActionResult Helper()
        {
            return null;
        }

        public string Ping()
        {
            return "pong";
        }
    }

    public class HelpDeskContext : System.Data.Entity.DbContext
    {
        public System.Data.Entity.DbSet<Ticket> Tickets { get; set; }
        public System.Data.Entity.DbSet<Customer> Customers { get; set; }
    }
}
