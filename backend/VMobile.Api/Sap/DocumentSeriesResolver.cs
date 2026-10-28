namespace VMobile.Api.Sap;

/// <summary>
/// Resolve a commercial series from the existing serieDelibery mapping,
/// then map it to SAP's distinct NNM1 Series IDs per document type.
/// Matches CardCode + Route + AddressId; retains AddressId2 in source rows for audit.
/// Does not assume that the credit-note series has the same name.
/// </summary>
public static class DocumentSeriesResolver
{
    public static ResolvedDocumentSeries Resolve(
        SeriesSelection selection,
        IEnumerable<SerieDeliberyRow> mappings,
        IEnumerable<SapNumberingSeries> numbering,
        IReadOnlyDictionary<string, string> creditNoteNameByCommercialSeries)
    {
        ArgumentNullException.ThrowIfNull(selection);
        ArgumentNullException.ThrowIfNull(mappings);
        ArgumentNullException.ThrowIfNull(numbering);
        ArgumentNullException.ThrowIfNull(creditNoteNameByCommercialSeries);

        var candidates = mappings.Where(m =>
            Eq(m.CardCode, selection.CardCode) &&
            Eq(m.Route, selection.Route) &&
            Eq(m.AddressId, selection.AddressId))
            .ToArray();

        if (candidates.Length != 1)
            throw new InvalidOperationException(
                $"Expected exactly one serieDelibery row; found {candidates.Length}.");

        var commercial = candidates[0].SeriesName.Trim();
        if (!creditNoteNameByCommercialSeries.TryGetValue(commercial, out var creditName)
            || string.IsNullOrWhiteSpace(creditName))
            throw new InvalidOperationException(
                $"No approved credit-note series mapping for '{commercial}'.");

        var all = numbering.ToArray();
        return new ResolvedDocumentSeries(
            commercial,
            FindUnique(all, "15", commercial),
            FindUnique(all, "13", commercial),
            FindUnique(all, "14", creditName));
    }

    private static int FindUnique(
        SapNumberingSeries[] series, string objectCode, string name)
    {
        var matches = series.Where(s =>
            s.ObjectCode == objectCode && Eq(s.SeriesName, name) && s.IsEnabled)
            .ToArray();
        if (matches.Length != 1)
            throw new InvalidOperationException(
                $"Expected one enabled SAP series for object {objectCode} and '{name}'; found {matches.Length}.");
        return matches[0].SeriesId;
    }

    private static bool Eq(string? left, string? right) =>
        string.Equals(left?.Trim(), right?.Trim(), StringComparison.OrdinalIgnoreCase);
}

public sealed record SeriesSelection(
    string CardCode, string Route, string AddressId);

public sealed record SerieDeliberyRow(
    string CardCode, string Route, string SeriesName, string AddressId, int? AddressId2);

public sealed record SapNumberingSeries(
    int SeriesId, string SeriesName, string ObjectCode, bool IsEnabled);

public sealed record ResolvedDocumentSeries(
    string CommercialSeriesName, int DeliverySeries, int InvoiceSeries, int CreditNoteSeries);
