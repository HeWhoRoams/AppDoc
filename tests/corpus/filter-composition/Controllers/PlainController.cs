using System.Web.Mvc;

namespace Contoso.Filters.Controllers
{
    public class PlainController : Controller
    {
        public ActionResult Index()
        {
            return View();
        }

    }
}
