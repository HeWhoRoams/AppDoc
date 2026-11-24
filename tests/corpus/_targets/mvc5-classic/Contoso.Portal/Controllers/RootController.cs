using System.Web.Mvc;

namespace Contoso.Portal.Controllers
{
    // Empty area name and empty prefix: a root controller, not an area.
    [RouteArea("", AreaPrefix = "")]
    [RoutePrefix("about")]
    public class RootController : BaseController
    {
        [Route("")]
        public ActionResult Index()
        {
            return View();
        }

        [Route("~/status")]
        public ActionResult Status()
        {
            return Content("ok");
        }

        [Route("team/{name?}")]
        [ActionName("Staff")]
        public ActionResult Team(string name)
        {
            return View();
        }
    }
}
