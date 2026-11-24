using System.Web.Mvc;

namespace Contoso.Chain.Controllers
{
    public class ChildController : Controller
    {
        public ActionResult Index()
        {
            return View();
        }

    }
}
