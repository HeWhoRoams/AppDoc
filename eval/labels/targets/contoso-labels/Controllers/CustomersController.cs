using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    public class CustomersController : Controller
    {
        [HttpPost]
        public ActionResult Update(int id)
        {
            new SqlCommand("UPDATE Customers SET Name = 'x' WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
