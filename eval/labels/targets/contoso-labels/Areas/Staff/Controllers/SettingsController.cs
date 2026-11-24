using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Areas.Staff.Controllers
{
    [Authorize]
    public class SettingsController : Controller
    {
        [HttpPost]
        public ActionResult Update(int id)
        {
            new SqlCommand("UPDATE Settings SET Value = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
