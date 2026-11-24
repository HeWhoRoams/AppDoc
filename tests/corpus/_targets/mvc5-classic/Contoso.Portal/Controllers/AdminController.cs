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
