using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    [ValidateAntiForgeryToken]
    public class HomeController : Controller
    {
        public ActionResult Index()
        {
            return View();
        }

        [HttpPost]
        public ActionResult Go(string target)
        {
            return RedirectToAction("Index");
        }
    }
}
