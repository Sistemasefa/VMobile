USE VMobileDB;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @route nvarchar(30), @card nvarchar(30), @whs nvarchar(20), @rfc nvarchar(32), @ticket bigint, @sale uniqueidentifier, @client uniqueidentifier, @n int, @item nvarchar(50), @batch nvarchar(100);
 DECLARE @demo TABLE(n int PRIMARY KEY, RouteCode nvarchar(30), CardCode nvarchar(30));
 INSERT @demo VALUES (1,N'A',N'DEMO-C001'),(2,N'A',N'DEMO-C002'),(3,N'B',N'DEMO-C003'),(4,N'B',N'DEMO-C004'),(5,N'C',N'DEMO-C005'),(6,N'C',N'DEMO-C006'),(7,N'D',N'DEMO-C007'),(8,N'D',N'DEMO-C008'),(9,N'E',N'DEMO-C009'),(10,N'E',N'DEMO-C010');
 SET @n=1;
 WHILE @n<=10
 BEGIN
  SELECT @route=RouteCode,@card=CardCode FROM @demo WHERE n=@n;
  SET @client=CONVERT(uniqueidentifier,CONCAT('d0000000-0000-4000-8000-',RIGHT(CONCAT('000000000000',@n),12)));
  IF NOT EXISTS(SELECT 1 FROM dbo.VM_Sales WITH(UPDLOCK,HOLDLOCK) WHERE ClientSaleId=@client)
  BEGIN
   SET @whs=NULL; SET @rfc=NULL;
   SELECT @whs=r.WhsCode,@rfc=c.FederalTaxID
   FROM dbo.VM_Routes r JOIN dbo.VM_RouteCustomers rc ON rc.RouteCode=r.RouteCode
   JOIN dbo.VM_Customers c ON c.CardCode=rc.CardCode
   JOIN dbo.VM_RouteCustomerAddresses a ON a.RouteCode=r.RouteCode AND a.CardCode=c.CardCode
   WHERE r.RouteCode=@route AND c.CardCode=@card AND a.AddressCode=N'DEMO-ENTREGA' AND r.IsActive=1 AND c.IsActive=1;
   IF @whs IS NULL OR NULLIF(LTRIM(RTRIM(@rfc)),N'') IS NULL THROW 51020,'Catalogos DEMO incompletos',1;
   SET @item=N'DEMO-PT001';
   SET @batch=CONCAT(N'DEMO-',@route,N'-001-L',CASE WHEN @n%2=1 THEN 1 ELSE 2 END);
   IF NOT EXISTS(SELECT 1 FROM dbo.VM_InventoryBatches WHERE WhsCode=@whs AND ItemCode=@item AND BatchNumber=@batch AND AvailableKg>=20+@n)
    THROW 51021,'Lote DEMO inexistente o insuficiente',1;
   EXEC dbo.VM_ReserveTicket @route,@ticket OUTPUT;
   SET @sale=NEWID();
   INSERT dbo.VM_Sales(SaleId,ClientSaleId,RouteCode,TicketNumber,CardCode,WhsCode,ShipToCode,CustomerRfc,ReferenceSap,Status)
   VALUES(@sale,@client,@route,@ticket,@card,@whs,N'DEMO-ENTREGA',@rfc,NULL,N'PENDIENTE');
   INSERT dbo.VM_SaleLines(SaleLineId,SaleId,LineNumber,ItemCode,BatchNumber,Pieces,WeightKg,PricePerKg,Classification)
   VALUES(NEWID(),@sale,1,@item,@batch,5+@n,20+@n,75+@n,N'Venta');
   INSERT dbo.VM_AuditEvents(EventId,RouteCode,SaleId,ActorId,EventType,Details)
   VALUES(NEWID(),@route,@sale,N'DEMO',N'VENTA_DEMO_CREADA',N'Prueba SQL sin sincronizacion ni descuento de existencias');
  END;
  SET @n=@n+1;
 END;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
SELECT s.RouteCode,s.TicketNumber,s.CardCode,l.ItemCode,l.BatchNumber,l.Pieces,l.WeightKg,l.PricePerKg,
 CASE WHEN UPPER(LTRIM(s.CustomerRfc)) LIKE N'XX%' THEN N'NV' ELSE N'F' END AS Tipo,
 CONCAT(CASE WHEN UPPER(LTRIM(s.CustomerRfc)) LIKE N'XX%' THEN N'NV' ELSE N'F' END,N' ',s.RouteCode,N' ',s.TicketNumber,N' VM') AS ReferenciaPrevista,
 s.ReferenceSap,s.Status
FROM dbo.VM_Sales s JOIN dbo.VM_SaleLines l ON l.SaleId=s.SaleId
WHERE s.CardCode LIKE N'DEMO-%'
ORDER BY s.RouteCode,s.TicketNumber,l.LineNumber;
GO
SELECT RouteCode,LastTicket FROM dbo.VM_RouteTicketCounters ORDER BY RouteCode;
GO
