using System.Web.Mvc;

namespace Contoso.Chain.Controllers
{
    public class VerbsController : Controller
    {
        [HttpPost]
        public ActionResult Save()
        {
            return View();
        }

        [HttpGet]
        public ActionResult List()
        {
            return View();
        }

    }
}
