using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    public class TagsController : Controller
    {
        [HttpPost]
        public ActionResult Merge(int id)
        {
            new SqlCommand("UPDATE Tags SET Parent = 1 WHERE Id = 2").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
