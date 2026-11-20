using System.Text.RegularExpressions;

namespace VMobile.Api.Services;

/// <summary>Referencia comercial estable, calculada al sincronizar hacia SAP.</summary>
public static class SaleReference
{
    private static readonly Regex RoutePattern = new("^[A-Z0-9_-]{1,20}$", RegexOptions.Compiled);

    public static bool IsGenericRfc(string? rfc)
    {
        var normalized = (rfc ?? "").Trim().ToUpperInvariant();
        return normalized.StartsWith("XX", StringComparison.Ordinal);
    }

    public static string Build(string routeCode, long ticketNumber, string? customerRfc)
    {
        if (string.IsNullOrWhiteSpace(routeCode)) throw new ArgumentException("La ruta es obligatoria.", nameof(routeCode));
        var route = routeCode.Trim().ToUpperInvariant();
        if (!RoutePattern.IsMatch(route)) throw new ArgumentException("Codigo de ruta invalido.", nameof(routeCode));
        if (ticketNumber <= 0) throw new ArgumentOutOfRangeException(nameof(ticketNumber));
        if (string.IsNullOrWhiteSpace(customerRfc)) throw new ArgumentException("El RFC debe validarse antes de sincronizar.", nameof(customerRfc));
        var prefix = IsGenericRfc(customerRfc) ? "NV" : "F";
        return $"{prefix} {route} {ticketNumber} VM";
    }
}
