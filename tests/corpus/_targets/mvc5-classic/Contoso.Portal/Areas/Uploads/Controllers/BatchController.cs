using System.IO;
using System.Web.Mvc;
using Contoso.Portal.Controllers;

namespace Contoso.Portal.Areas.Uploads.Controllers
{
    [ RouteArea ( AreaPrefix="uploads" ) ]
    [ RoutePrefix ( "batch" ) ]
    public class BatchController : BaseController
    {
        [Route("run")]
        public ActionResult Run()
        {
            File.WriteAllText(Server.MapPath("~/App_Data/batch.log"), "started");
            return Content("started");
        }
    }
}
