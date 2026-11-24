using System.Web.Mvc;

namespace Contoso.Chain.Controllers
{
    public class NamedController : Controller
    {
        public ActionResult Index()
        {
            return View();
        }

    }
}
