var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
app.MapGet("/", () => "sample");
app.Run();
