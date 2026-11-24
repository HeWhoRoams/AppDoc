using System.Web.Mvc;

namespace Contoso.Portal.Controllers
{
    [Authorize]
    public class AccountController : BaseController
    {
        [AllowAnonymous]
        [Route("~/signin")]
        public ActionResult Login()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Manage(string displayName)
        {
            return RedirectToAction("Index", "Home");
        }

        [HttpGet]
        public ActionResult Details()
        {
            return View();
        }
    }
}
