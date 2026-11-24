using System.IO;
using System.Web;
using System.Web.Mvc;
using Contoso.Portal.Controllers;
using Contoso.Shared.Layout;

namespace Contoso.Portal.Areas.Uploads.Controllers
{
    [RouteArea(AreaPrefix = "uploads")]
    [ContosoLayout("Narrow")]
    public class UploadsController : BaseController
    {
        public ActionResult Index()
        {
            return View();
        }

        // Writes a file; no guard and no <location> rule covers this area.
        public ActionResult Save(HttpPostedFileBase file)
        {
            var name = Path.GetFileName(file.FileName);
            file.SaveAs(Server.MapPath("~/App_Data/uploads/" + name));
            return RedirectToAction("Index");
        }
    }
}
