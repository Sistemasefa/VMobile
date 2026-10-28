using System.Data;
using Microsoft.Data.SqlClient;

namespace VMobile.Api.Data;

public sealed record OrderSummary(Guid OrderId, string CardCode, string Status, DateTime CreatedAtUtc);
public sealed record NewOrder(Guid ClientOrderId, string CardCode, string? ShipToCode, string? Notes);
public sealed class OrderRepository(IConfiguration configuration)
{
    private SqlConnection OpenConnection() =>
        new(configuration.GetConnectionString("VMobile")
            ?? throw new InvalidOperationException("Missing ConnectionStrings:VMobile"));

    public async Task<Guid> CreateAsync(NewOrder order, CancellationToken cancellationToken)
    {
        if (order.ClientOrderId == Guid.Empty || string.IsNullOrWhiteSpace(order.CardCode))
            throw new ArgumentException("ClientOrderId and CardCode are required.");
        var id = Guid.NewGuid();
        await using var connection = OpenConnection();
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand("""
            INSERT INTO dbo.VM_Orders (OrderId, ClientOrderId, CardCode, ShipToCode, Notes)
            VALUES (@id, @clientId, @card, @shipTo, @notes)
            """, connection);
        command.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = id;
        command.Parameters.Add("@clientId", SqlDbType.UniqueIdentifier).Value = order.ClientOrderId;
        command.Parameters.Add("@card", SqlDbType.NVarChar, 30).Value = order.CardCode.Trim();
        command.Parameters.Add("@shipTo", SqlDbType.NVarChar, 100).Value = (object?)order.ShipToCode ?? DBNull.Value;
        command.Parameters.Add("@notes", SqlDbType.NVarChar, 1000).Value = (object?)order.Notes ?? DBNull.Value;
        await command.ExecuteNonQueryAsync(cancellationToken);
        return id;
    }

    public async Task<IReadOnlyList<OrderSummary>> ListAsync(CancellationToken cancellationToken)
    {
        var result = new List<OrderSummary>();
        await using var connection = OpenConnection();
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand("""
            SELECT TOP (100) OrderId, CardCode, Status, CreatedAtUtc
            FROM dbo.VM_Orders ORDER BY CreatedAtUtc DESC
            """, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            result.Add(new OrderSummary(reader.GetGuid(0), reader.GetString(1),
                reader.GetString(2), reader.GetDateTime(3)));
        return result;
    }
}
