using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    public class FeedbackController : Controller
    {
        public ActionResult Submit(string text)
        {
            new SqlCommand("INSERT INTO Feedback (Text) VALUES ('x')").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
