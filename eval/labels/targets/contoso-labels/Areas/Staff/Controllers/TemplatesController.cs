using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Areas.Staff.Controllers
{
    [Authorize]
    public class TemplatesController : Controller
    {
        [HttpPost]
        public ActionResult Create(int id)
        {
            new SqlCommand("INSERT INTO Templates (Id) VALUES (1)").ExecuteNonQuery();
            return RedirectToAction("Index");
        }

        [HttpPost]
        public ActionResult Remove(int id)
        {
            new SqlCommand("DELETE FROM Templates WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
