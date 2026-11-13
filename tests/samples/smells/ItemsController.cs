using Microsoft.AspNetCore.Mvc;

namespace Smells;

public class ItemsController : Controller
{
    [HttpGet("items/{id}/remove")]
    public IActionResult Remove(int id)
    {
        var item = _context.Items.Find(id);
        _context.Items.Remove(item);
        _context.SaveChanges();
        return Ok();
    }

    [HttpGet]
    public IActionResult List()
    {
        var names = new List<string>();
        names.Add("x");
        return Ok(names);
    }

    [HttpPost]
    public IActionResult Save()
    {
        _context.SaveChanges();
        return Ok();
    }

    // [HttpGet]
    // public IActionResult Old() { _context.SaveChanges(); }

    public const string ConnectionPassword = "p@ssw0rd!";
    private const string TokenHeader = "X-Auth-Token";
    private static readonly string ApiKey = "k-12345";
}
