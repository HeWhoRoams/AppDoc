using System.Web.Mvc;

namespace Contoso.Filters.Controllers
{
    [AllowAnonymous]
    public class OpenController : Controller
    {
        public ActionResult Index()
        {
            return View();
        }

    }
}
