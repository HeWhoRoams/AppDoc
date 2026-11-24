using System.Web.Mvc;

namespace Contoso.Filters.Controllers
{
    [Authorize(Roles = "Admins")]
    public class OverrideController : Controller
    {
        [OverrideAuthorization]
        public ActionResult Index()
        {
            return View();
        }

    }
}
