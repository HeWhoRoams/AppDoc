using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Areas.Staff.Controllers
{
    [Authorize(Roles = "Admins")]
    public class RolesController : Controller
    {
        [HttpPost]
        public ActionResult Save(int id)
        {
            new SqlCommand("UPDATE Roles SET Name = 'x' WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
