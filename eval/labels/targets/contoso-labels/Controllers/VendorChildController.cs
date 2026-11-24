using System.Data.SqlClient;
using System.Web.Mvc;
using Fabrikam.Web;

namespace Contoso.Labels.Controllers
{
    [Authorize(Roles = "Clerks")]
    public class VendorChildController : FabrikamBaseController
    {
        [HttpPost]
        public ActionResult Save(int id)
        {
            new SqlCommand("UPDATE Safe SET F = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
