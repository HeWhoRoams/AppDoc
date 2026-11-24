using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    [Authorize(Roles = "Clerks")]
    public class SafeOwnController : Controller
    {
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Save(int id)
        {
            new SqlCommand("UPDATE Safe SET A = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
