using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    [Authorize(Roles = "Clerks")]
    [ValidateAntiForgeryToken]
    public class SafeClassController : Controller
    {
        [HttpPost]
        public ActionResult Save(int id)
        {
            new SqlCommand("UPDATE Safe SET B = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
