var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthentication();
var app = builder.Build();
app.UseAuthorization();
app.MapGet("/", () => "sample");
app.Run();
