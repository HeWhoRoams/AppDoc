using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    public class ReportsController : Controller
    {
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Search(string term)
        {
            new SqlCommand("SELECT Id FROM Orders WHERE Name = 'x'").ExecuteReader();
            return View();
        }
    }
}
