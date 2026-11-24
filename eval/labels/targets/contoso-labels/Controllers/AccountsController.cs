using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    public class AccountsController : Controller
    {
        [Authorize(Roles = "Clerks")]
        [HttpPost]
        public ActionResult Close(int id)
        {
            new SqlCommand("UPDATE Accounts SET Open = 0 WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
