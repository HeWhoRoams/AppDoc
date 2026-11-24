using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Areas.Ops.Controllers
{
    [Authorize]
    [ValidateAntiForgeryToken]
    public class JobsController : Controller
    {
        [HttpPost]
        public ActionResult Run(int id)
        {
            new SqlCommand("UPDATE Jobs SET State = 1 WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
