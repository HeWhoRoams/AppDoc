using System.Web.Mvc;
using Contoso.Portal.Controllers;
using Contoso.Portal.Infrastructure;
using Contoso.Shared.Security;

namespace Contoso.Portal.Areas.Billing.Controllers
{
    [RouteArea("Billing", AreaPrefix = "billing")]
    [RoutePrefix("invoices")]
    [Authorize]
    [ContosoGuard(Roles.Finance, MvcApplication.Mode, Groups.FinanceGroup, Accounts.ServiceAccount, Accounts.ServicePassword)]
    public class InvoicesController : BaseController
    {
        [Route("{id:int?}")]
        public ActionResult Index(int? id)
        {
            return View();
        }

        [HttpPost]
        [Route("approve")]
        public ActionResult Approve(int id)
        {
            return RedirectToAction("Index");
        }

        // A method-level use whose arity differs from the class-level use.
        [ContosoGuard(Roles.Admin, MvcApplication.Mode, Groups.FinanceGroup, Accounts.ServiceAccount)]
        [HttpPost]
        [Route("refund")]
        public ActionResult Refund(int id)
        {
            if (MvcApplication.Mode == "Production")
            {
                if (!HasRole(User, Roles.Finance, Groups.FinanceGroup))
                {
                    return new HttpUnauthorizedResult();
                }
            }
            return RedirectToAction("Index");
        }
    }
}
