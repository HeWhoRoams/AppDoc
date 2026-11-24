using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Areas.Staff.Controllers
{
    [Authorize]
    [ValidateAntiForgeryToken]
    public class LookupsController : Controller
    {
        [HttpPost]
        public ActionResult Filter(string term)
        {
            new SqlCommand("SELECT Id FROM Users WHERE Name = 'x'").ExecuteReader();
            return View();
        }

        [HttpPost]
        public ActionResult Go(string target)
        {
            return RedirectToAction("Index");
        }
    }
}
