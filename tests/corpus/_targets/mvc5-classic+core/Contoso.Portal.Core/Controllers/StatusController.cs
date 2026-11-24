using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Contoso.Portal.Core.Controllers
{
    [ApiController]
    [Route("api/status")]
    public class StatusController : ControllerBase
    {
        [HttpGet]
        public IActionResult Get() => Ok("ok");

        [HttpPost("reset")]
        [Authorize(Roles = "PortalAdmins")]
        public IActionResult Reset() => NoContent();
    }
}
