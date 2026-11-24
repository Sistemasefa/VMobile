USE VMobileDB;
GO
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH('dbo.VM_Customers','FederalTaxID') IS NULL
        ALTER TABLE dbo.VM_Customers ADD FederalTaxID nvarchar(32) NULL;

    EXEC sys.sp_executesql N'
        UPDATE dbo.VM_Customers
        SET FederalTaxID = CASE
            WHEN CardCode IN (N''DEMO-C002'',N''DEMO-C004'',N''DEMO-C006'',N''DEMO-C008'',N''DEMO-C010'')
                THEN N''XX-DEMO''
            ELSE CONCAT(N''DEMO-RFC-'', RIGHT(CardCode,3))
        END,
        UpdatedAtUtc = SYSUTCDATETIME()
        WHERE CardCode IN (
            N''DEMO-C001'',N''DEMO-C002'',N''DEMO-C003'',N''DEMO-C004'',N''DEMO-C005'',
            N''DEMO-C006'',N''DEMO-C007'',N''DEMO-C008'',N''DEMO-C009'',N''DEMO-C010''
        )
        AND FederalTaxID IS NULL;
    ';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT r.RouteCode,c.CardCode,c.CardName,c.FederalTaxID,
    CASE
        WHEN NULLIF(LTRIM(RTRIM(c.FederalTaxID)),N'') IS NULL THEN N'PENDIENTE'
        WHEN UPPER(LTRIM(c.FederalTaxID)) LIKE N'XX%' THEN N'NV'
        ELSE N'F'
    END AS TipoDocumento
FROM dbo.VM_Customers c
JOIN dbo.VM_RouteCustomers r ON r.CardCode=c.CardCode
WHERE c.CardCode LIKE N'DEMO-%'
ORDER BY r.RouteCode,c.CardCode;
GO
