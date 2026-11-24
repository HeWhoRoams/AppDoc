using System.Web.Mvc;
using HelpDesk.Infrastructure;

namespace HelpDesk.Controllers
{
    // BannerAttribute is not defined in the Target: three uses make it a guard candidate (or a layout attribute).
    [Banner("Reports")]
    [StaffOnly(Roles = Rolenames.Support)]
    public class ReportsController : Controller
    {
        [Banner("Daily")]
        public ActionResult Daily()
        {
            return View();
        }

        [Banner("Weekly")]
        public ActionResult Weekly()
        {
            if (!User.IsInRole(Rolenames.Support) && !Allowed(Rolenames.Support, Rolenames.Supervisor))
            {
                return new HttpUnauthorizedResult();
            }
            return View();
        }

        private bool Allowed(string a, string b)
        {
            return User.IsInRole(a) || User.IsInRole(b);
        }
    }
}
