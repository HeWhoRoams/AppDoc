using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Areas.Staff.Controllers
{
    [Authorize]
    public class UsersController : Controller
    {
        [HttpPost]
        public ActionResult Save(int id)
        {
            new SqlCommand("UPDATE Users SET Name = 'x' WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }

        [HttpPost]
        public ActionResult Drop(int id)
        {
            new SqlCommand("DELETE FROM Users WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
