using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddAuthorization();
var app = builder.Build();
app.UseAuthorization();
app.MapControllers();
app.Run();

public static class Entry
{
    public static void Main(string[] args)
    {
    }
}
