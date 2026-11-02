using System.Web.Http;

namespace HelpDesk.Controllers
{
    [RoutePrefix("api/v1/tickets")]
    public class ApiTicketsController : ApiController
    {
        [HttpGet]
        [Route("{id}")]
        public IHttpActionResult GetTicket(int id)
        {
            return Ok();
        }

        public string Get()
        {
            return "[]";
        }
    }
}
