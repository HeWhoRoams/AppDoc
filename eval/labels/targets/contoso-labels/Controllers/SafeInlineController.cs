using System.Data.SqlClient;
using System.Web.Helpers;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    [Authorize(Roles = "Clerks")]
    public class SafeInlineController : Controller
    {
        [HttpPost]
        public ActionResult Save(int id)
        {
            AntiForgery.Validate();
            new SqlCommand("UPDATE Safe SET E = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
