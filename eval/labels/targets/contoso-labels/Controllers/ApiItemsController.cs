using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web.Http;

namespace Contoso.Labels.Controllers
{
    public class ApiItemsController : ApiController
    {
        [HttpGet]
        public IEnumerable<string> GetItems()
        {
            new SqlCommand("SELECT Name FROM Items").ExecuteReader();
            return new List<string>();
        }

        [HttpPost]
        public IHttpActionResult PostItem(string name)
        {
            return Ok();
        }
    }
}
