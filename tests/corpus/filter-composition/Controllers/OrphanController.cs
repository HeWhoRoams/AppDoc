using System.Web.Mvc;
using Contoso.Shared.Web;

namespace Contoso.Filters.Controllers
{
    public class OrphanController : SharedControllerBase
    {
        public ActionResult Index()
        {
            return View();
        }
    }
}
