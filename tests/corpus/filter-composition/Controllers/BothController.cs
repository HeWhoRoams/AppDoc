using System.Web.Mvc;

namespace Contoso.Filters.Controllers
{
    [Authorize(Roles = "Admins", Users = "pat")]
    public class BothController : Controller
    {
        public ActionResult Index()
        {
            return View();
        }

    }
}
