using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    public class OrdersController : Controller
    {
        [HttpPost]
        public ActionResult Create(int id)
        {
            new SqlCommand("INSERT INTO Orders (Id) VALUES (1)").ExecuteNonQuery();
            return RedirectToAction("Index");
        }

        [HttpPost]
        public ActionResult Remove(int id)
        {
            new SqlCommand("DELETE FROM Orders WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
