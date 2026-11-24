using System.Web.Mvc;
using Contoso.Portal.Infrastructure;
using Contoso.Shared.Security;

namespace Contoso.Portal.Controllers
{
    [Authorize]
    [ContosoGuard(Roles.Admin, MvcApplication.Mode, Groups.OpsGroup, Accounts.ServiceAccount)]
    public class AdminController : BaseController
    {
        public ActionResult Index()
        {
            return View();
        }

        [HttpPost]
        [Authorize(Roles = "PortalAdmins, ops.lead@contoso.test, S-1-5-21-1004336348-1177238915-682003330-512")]
        public ActionResult Reset(int id)
        {
            if (!HasRole(User, Roles.Admin, Groups.OpsGroup))
            {
                return new HttpUnauthorizedResult();
            }
            return RedirectToAction("Index");
        }
    }
}
