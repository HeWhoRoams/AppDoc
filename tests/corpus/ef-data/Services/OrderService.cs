using Microsoft.EntityFrameworkCore;

public class OrderService
{
    private readonly ShopContext _db;
    public async Task<List<Order>> Open() =>
        await _db.Orders.Where(o => o.Open).ToListAsync();
}
