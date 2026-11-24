using System.Web.Mvc;
using Contoso.Portal.Controllers;
using Contoso.Portal.Infrastructure;
using Contoso.Shared.Security;

namespace Contoso.Portal.Areas.Archive.Controllers
{
    [ContosoGuard(Roles.Auditor, MvcApplication.Mode, Groups.OpsGroup, Accounts.ServiceAccount)]
    public class ExportController : BaseController
    {
        public ActionResult Index()
        {
            return View();
        }

        [HttpGet]
        public ActionResult Download(int id)
        {
            return File("~/App_Data/exports/" + id + ".csv", "text/csv");
        }
    }
}
