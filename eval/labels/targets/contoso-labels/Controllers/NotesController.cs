using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    public class NotesController : Controller
    {
        [HttpPost]
        public ActionResult Add(string text)
        {
            new SqlCommand("INSERT INTO Notes (Text) VALUES ('x')").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
