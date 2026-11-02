using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HelpDesk.TicketApi.Controllers
{
    // Modern ASP.NET Core idioms: class-level [Authorize] (security boundary), a
    // controller-level [Route("api/v1/[controller]")] template, a named route
    // [HttpGet(Name = nameof(...))], a named route with a template segment
    // [HttpGet("{id}", Name = nameof(...))], and a bare [HttpPost] (no explicit path).
    // These are the four shapes the C# Core endpoint extractor historically dropped;
    // the golden assertions pin that each now extracts a real (composed) route.
    [Authorize]
    [ApiController]
    [Route("api/v1/[controller]")]
    public class OrdersController : ControllerBase
    {
        /// <summary>
        /// List all orders (named route, no explicit path).
        /// </summary>
        [HttpGet(Name = nameof(ListOrders))]
        public IActionResult ListOrders()
        {
            return Ok(new[] { 1, 2, 3 });
        }

        /// <summary>
        /// Get a single order by its id (named route with a {id} segment).
        /// </summary>
        [HttpGet("{id}", Name = nameof(GetOrder))]
        public IActionResult GetOrder(int id)
        {
            return Ok(new { id });
        }

        /// <summary>
        /// Create a new order (bare [HttpPost] — conventional /{controller}/{action}).
        /// </summary>
        [HttpPost]
        public IActionResult CreateOrder(OrderDto order)
        {
            return Ok(order);
        }
    }

    public class OrderDto
    {
        public int Id { get; set; }
        public string Label { get; set; }
    }
}
