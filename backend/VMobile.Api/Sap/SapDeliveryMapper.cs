using System.Text.Json.Serialization;

namespace VMobile.Api.Sap;

/// <summary>
/// Converts captured sale allocations into SAP B1 DeliveryNotes lines.
/// Each batch allocation becomes exactly one SAP document line.
/// </summary>
public static class SapDeliveryMapper
{
    public const string Sale = "Venta";
    public const string Promotion = "Promocion";

    public static IReadOnlyList<SapDocumentLine> BuildLines(
        IEnumerable<SaleBatchAllocation> allocations)
    {
        ArgumentNullException.ThrowIfNull(allocations);
        var lines = new List<SapDocumentLine>();
        foreach (var allocation in allocations)
        {
            ArgumentNullException.ThrowIfNull(allocation);
            if (string.IsNullOrWhiteSpace(allocation.ItemCode) ||
                string.IsNullOrWhiteSpace(allocation.WarehouseCode) ||
                string.IsNullOrWhiteSpace(allocation.BatchNumber))
                throw new ArgumentException("Item, warehouse and batch are required.");
            if (allocation.WeightKg <= 0 || allocation.Pieces <= 0)
                throw new ArgumentOutOfRangeException(nameof(allocations),
                    "WeightKg and Pieces must be positive.");
            if (allocation.PricePerKg < 0)
                throw new ArgumentOutOfRangeException(nameof(allocations),
                    "PricePerKg cannot be negative.");
            if (allocation.Classification is not (Sale or Promotion))
                throw new ArgumentException(
                    "Classification must be 'Venta' or 'Promocion'.");

            lines.Add(new SapDocumentLine(
                allocation.ItemCode.Trim(),
                allocation.WeightKg,
                allocation.Pieces,
                allocation.Classification,
                allocation.WarehouseCode.Trim(),
                allocation.PricePerKg,
                new[] { new SapBatchNumber(allocation.BatchNumber.Trim(), allocation.WeightKg) }
            ));
        }
        if (lines.Count == 0)
            throw new ArgumentException("At least one batch allocation is required.");
        return lines;
    }
}

public sealed record SaleBatchAllocation(
    string ItemCode,
    string WarehouseCode,
    string BatchNumber,
    decimal WeightKg,
    decimal Pieces,
    decimal PricePerKg,
    string Classification);

public sealed record SapBatchNumber(
    [property: JsonPropertyName("BatchNumber")] string BatchNumber,
    [property: JsonPropertyName("Quantity")] decimal Quantity);

public sealed record SapDocumentLine(
    [property: JsonPropertyName("ItemCode")] string ItemCode,
    [property: JsonPropertyName("Quantity")] decimal Quantity,
    [property: JsonPropertyName("U_Piezas")] decimal Pieces,
    [property: JsonPropertyName("U_conProduct")] string Classification,
    [property: JsonPropertyName("WarehouseCode")] string WarehouseCode,
    [property: JsonPropertyName("UnitPrice")] decimal UnitPrice,
    [property: JsonPropertyName("BatchNumbers")] IReadOnlyList<SapBatchNumber> BatchNumbers);
