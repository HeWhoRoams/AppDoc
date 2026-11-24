using System.Web.Mvc;

namespace Contoso.Coverage.Areas.Billing.Controllers
{
    [RouteArea("Billing", AreaPrefix = "billing")]
    public class InvoicesController : Controller
    {
        [HttpPost]
        [Route("approve")]
        public ActionResult Approve(int id)
        {
            return RedirectToAction("Index");
        }
    }
}
