using System.Web.Mvc;

namespace Contoso.Filters.Controllers
{
    [AllowAnonymous]
    public class LockedController : Controller
    {
        public ActionResult Index()
        {
            return View();
        }

    }
}
