using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    [Authorize(Roles = "Clerks")]
    public class SafeChildController : TokenBaseController
    {
        [HttpPost]
        public ActionResult Save(int id)
        {
            new SqlCommand("UPDATE Safe SET C = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
