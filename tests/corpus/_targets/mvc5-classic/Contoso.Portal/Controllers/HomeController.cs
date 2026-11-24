using System.Web.Mvc;
using Contoso.Shared.Layout;

namespace Contoso.Portal.Controllers
{
    [ContosoLayout("Wide")]
    public class HomeController : BaseController
    {
        public ActionResult Index()
        {
            var banner = "Welcome";
#if DEBUG
            banner = "Welcome (debug build)";
#endif
            ViewBag.Banner = banner;
            return View();
        }

        public ActionResult Contact()
        {
            return View();
        }

        // No verb attribute: MVC 5 accepts every verb, and this action changes state.
        public ActionResult Subscribe(string email)
        {
            System.IO.File.AppendAllText(Server.MapPath("~/App_Data/subscribers.txt"), email + "\n");
            return RedirectToAction("Index");
        }
    }
}
