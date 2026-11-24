using Microsoft.EntityFrameworkCore;

public class ShopContext : DbContext
{
    public DbSet<Order> Orders { get; set; }
}
