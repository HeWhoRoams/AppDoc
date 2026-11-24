using System.Data.SqlClient;
using System.Web.Mvc;

namespace Contoso.Labels.Areas.Ops.Controllers
{
    [Authorize]
    [ValidateAntiForgeryToken]
    public class QueuesController : Controller
    {
        [HttpPost]
        public ActionResult Clear(int id)
        {
            new SqlCommand("DELETE FROM Queues WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }

        [HttpPost]
        public ActionResult Pause(int id)
        {
            new SqlCommand("UPDATE Queues SET Paused = 1 WHERE Id = 1").ExecuteNonQuery();
            return RedirectToAction("Index");
        }
    }
}
