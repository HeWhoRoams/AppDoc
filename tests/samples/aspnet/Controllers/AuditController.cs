using System.Web.Mvc;

namespace HelpDesk.Controllers
{
    public static class Auditroles
    {
#if DEBUG
        public const string Reviewer = "Everyone";
#else
        public const string Reviewer = "Reviewer";
#endif
        public const string Approver = "Approver";
    }

    public class AuditController : Controller
    {
        [Authorize(Roles = Auditroles.Reviewer)]
        public ActionResult Index()
        {
            return View();
        }

        [Authorize(Roles = Auditroles.Approver)]
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Approve(int id)
        {
            if (Settings.Mode == AppMode.Production && !CheckAccess(Auditroles.Reviewer, Auditroles.Approver))
            {
                return new HttpUnauthorizedResult();
            }
            return RedirectToAction("Index");
        }
    }
}
