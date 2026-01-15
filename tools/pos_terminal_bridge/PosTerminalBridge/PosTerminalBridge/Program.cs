using System.Collections.Concurrent;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<PaymentStore>();
builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
});

var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new
{
    ok = true,
    name = "PosTerminalBridge",
    version = "1.0.0",
    now = DateTimeOffset.Now
}));

app.MapGet("/api/providers", () => Results.Ok(new[]
{
    new { code = "mercadoPagoPointSmart", label = "Mercado Pago Point Smart" },
    new { code = "prosepago", label = "Prosepago" },
}));

// Crear un intento de cobro (PENDING)
app.MapPost("/api/terminal/charge", (ChargeRequest req, PaymentStore store) =>
{
    if (req.Amount <= 0) return Results.BadRequest(new { error = "amount_invalid" });
    if (string.IsNullOrWhiteSpace(req.Reference)) return Results.BadRequest(new { error = "reference_required" });
    if (string.IsNullOrWhiteSpace(req.Provider)) return Results.BadRequest(new { error = "provider_required" });

    var id = Guid.NewGuid().ToString("N");
    var p = new PaymentSession
    {
        Id = id,
        Provider = req.Provider.Trim(),
        Amount = req.Amount,
        Reference = req.Reference.Trim(),
        Status = PaymentStatus.Pending,
        CreatedAt = DateTimeOffset.Now
    };

    store.Upsert(p);

    // Aquí es donde ENCHUFAS el driver real:
    // - Mercado Pago Point Smart: disparas el cobro vía su integración (cloud/SDK)
    // - Prosepago: disparas cobro vía su integración (SDK/driver)
    //
    // Por ahora, queda PENDING hasta que alguien (driver o panel) lo apruebe/decline.

    return Results.Ok(new
    {
        paymentId = id,
        status = p.Status.ToString().ToUpperInvariant()
    });
});

// Consultar estado
app.MapGet("/api/terminal/status/{paymentId}", (string paymentId, PaymentStore store) =>
{
    var p = store.Get(paymentId);
    if (p is null) return Results.NotFound(new { error = "not_found" });

    return Results.Ok(new
    {
        paymentId = p.Id,
        provider = p.Provider,
        amount = p.Amount,
        reference = p.Reference,
        status = p.Status.ToString().ToUpperInvariant(),
        message = p.Message
    });
});

// Cancelar
app.MapPost("/api/terminal/cancel/{paymentId}", (string paymentId, PaymentStore store) =>
{
    var p = store.Get(paymentId);
    if (p is null) return Results.NotFound(new { error = "not_found" });

    if (p.Status is PaymentStatus.Approved or PaymentStatus.Declined)
        return Results.BadRequest(new { error = "already_final" });

    p.Status = PaymentStatus.Cancelled;
    p.Message = "Cancelado desde POS/bridge.";
    store.Upsert(p);

    return Results.Ok(new { ok = true });
});

// Panel local (para pruebas / fallback)
app.MapGet("/", (PaymentStore store) =>
{
    var list = store.ListLast(30);
    var html = $@"
<!doctype html>
<html>
<head>
  <meta charset='utf-8' />
  <title>POS Terminal Bridge</title>
  <style>
    body {{ font-family: sans-serif; margin: 18px; }}
    table {{ border-collapse: collapse; width: 100%; }}
    td, th {{ border: 1px solid #ddd; padding: 8px; font-size: 14px; }}
    th {{ background: #f2f2f2; }}
    .PENDING {{ color: #b26a00; font-weight: 700; }}
    .APPROVED {{ color: #0a7a0a; font-weight: 700; }}
    .DECLINED {{ color: #b00020; font-weight: 700; }}
    .CANCELLED {{ color: #555; font-weight: 700; }}
    button {{ padding: 6px 10px; margin-right: 6px; }}
  </style>
</head>
<body>
  <h2>POS Terminal Bridge</h2>
  <p>Estado: <code>/health</code> · API: <code>/api/terminal/...</code></p>
  <table>
    <tr>
      <th>ID</th><th>Provider</th><th>Amount</th><th>Reference</th><th>Status</th><th>Acciones</th>
    </tr>";

    foreach (var p in list)
    {
        html += $@"
    <tr>
      <td><code>{p.Id}</code></td>
      <td>{p.Provider}</td>
      <td>${p.Amount:F2}</td>
      <td>{p.Reference}</td>
      <td class='{p.Status.ToString().ToUpperInvariant()}'>{p.Status.ToString().ToUpperInvariant()}</td>
      <td>";
        if (p.Status == PaymentStatus.Pending)
        {
            html += $@"
        <form style='display:inline' method='post' action='/ui/approve/{p.Id}'><button type='submit'>Aprobar</button></form>
        <form style='display:inline' method='post' action='/ui/decline/{p.Id}'><button type='submit'>Declinar</button></form>";
        }
        html += "</td></tr>";
    }

    html += @"
  </table>
</body>
</html>";

    return Results.Content(html, "text/html");
});

app.MapPost("/ui/approve/{paymentId}", (string paymentId, PaymentStore store) =>
{
    var p = store.Get(paymentId);
    if (p is null) return Results.NotFound();
    if (p.Status != PaymentStatus.Pending) return Results.BadRequest();

    p.Status = PaymentStatus.Approved;
    p.Message = "Aprobado.";
    store.Upsert(p);
    return Results.Redirect("/");
});

app.MapPost("/ui/decline/{paymentId}", (string paymentId, PaymentStore store) =>
{
    var p = store.Get(paymentId);
    if (p is null) return Results.NotFound();
    if (p.Status != PaymentStatus.Pending) return Results.BadRequest();

    p.Status = PaymentStatus.Declined;
    p.Message = "Declinado.";
    store.Upsert(p);
    return Results.Redirect("/");
});

// localhost only (recomendado)
app.Run("http://127.0.0.1:5055");

// -------------------------

record ChargeRequest(string Provider, double Amount, string Reference);

enum PaymentStatus { Pending, Approved, Declined, Cancelled }

class PaymentSession
{
    public string Id { get; set; } = "";
    public string Provider { get; set; } = "";
    public double Amount { get; set; }
    public string Reference { get; set; } = "";
    public PaymentStatus Status { get; set; }
    public string? Message { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

class PaymentStore
{
    private readonly ConcurrentDictionary<string, PaymentSession> _map = new();

    public void Upsert(PaymentSession p) => _map[p.Id] = p;

    public PaymentSession? Get(string id)
        => _map.TryGetValue(id, out var p) ? p : null;

    public IEnumerable<PaymentSession> ListLast(int n)
        => _map.Values.OrderByDescending(x => x.CreatedAt).Take(n);
}
