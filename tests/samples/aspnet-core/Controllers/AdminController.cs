using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HelpDesk.TicketApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin,Support")]
    public class AdminController : ControllerBase
    {
        [HttpGet("users/{id}")]
        [Authorize(Policy = "CanViewUsers")]
        public IActionResult GetUser(int id)
        {
            if (id <= 0)
            {
                return BadRequest("User id must be positive.");
            }
            return NotFound("No such user.");
        }

        [AllowAnonymous]
        [HttpGet("health")]
        public IActionResult Health() => Ok();

        [HttpDelete("{id}")]
        public IActionResult Remove(int id)
        {
            // return BadRequest("Commented out message must not appear.");
            return Problem(detail: "Removal is not supported.", statusCode: 501);
        }
    }
}
