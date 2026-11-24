using System.Web.Mvc;
using Contoso.Portal.Controllers;
using Contoso.Shared.Layout;

namespace Contoso.Portal.Areas.Public.Controllers
{
    [AllowAnonymous]
    [ContosoLayout("Narrow")]
    public class NoticesController : BaseController
    {
        public ActionResult Index()
        {
            return View();
        }

        public ActionResult Feed()
        {
            return Json(new { items = new string[0] }, JsonRequestBehavior.AllowGet);
        }
    }
}
