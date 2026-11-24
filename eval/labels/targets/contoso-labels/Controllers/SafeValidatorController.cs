using System.Data.SqlClient;
using System.Web.Mvc;
using Contoso.Labels.Filters;

namespace Contoso.Labels.Controllers
{
    [Authorize(Roles = "Clerks")]
    public class SafeValidatorController : Controller
    {
        [SiteToken]
        [HttpPost]
        public ActionResult Save(int id)
        {
            new SqlCommand("UPDATE Safe SET D = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
