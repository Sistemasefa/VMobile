using System.Net.Http.Json;
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient<SapServiceLayerClient>((sp, http) => {
    var url = sp.GetRequiredService<IConfiguration>()["Sap:BaseUrl"] ?? throw new InvalidOperationException("Missing SAP URL");
    if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Scheme != "https")
        throw new InvalidOperationException("SAP URL must use HTTPS");
    http.BaseAddress = new Uri(url.TrimEnd('/') + "/");
    http.Timeout = TimeSpan.FromSeconds(30);
});
var app = builder.Build();
app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "VMobile" }));
if (app.Environment.IsDevelopment())
    app.MapGet("/dev/sap-login-check", async (SapServiceLayerClient sap, CancellationToken ct) => {
        try { return (await sap.Login(ct)) ? Results.Ok(new { authenticated = true }) : Results.StatusCode(503); }
        catch (HttpRequestException) { return Results.StatusCode(503); }
    });
app.Run();
public sealed class SapServiceLayerClient(HttpClient http, IConfiguration cfg) {
    public async Task<bool> Login(CancellationToken ct) {
        string Required(string key) => cfg[key] is { Length: > 0 } v ? v : throw new InvalidOperationException("Missing " + key);
        using var response = await http.PostAsJsonAsync("b1s/v2/Login", new {
            CompanyDB = Required("Sap:CompanyDB"),
            UserName = Required("Sap:UserName"),
            Password = Required("Sap:Password")
        }, ct);
        return response.IsSuccessStatusCode;
    }
}
// Prototype only: login diagnostic, not a persistent SAP session or production API.
