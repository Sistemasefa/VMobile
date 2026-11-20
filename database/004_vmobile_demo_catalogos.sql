/*
VMobile DEMO - Fase 2: clientes, direcciones, articulos, lotes y asignaciones.
Requiere haber ejecutado 003_vmobile_demo_base.sql.
No conecta ni modifica SAP. No genera ventas reales.
Idempotente para claves DEMO; no modifica filas ya existentes.
*/
USE VMobileDB;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;

 IF EXISTS (
   SELECT 1 FROM (VALUES (N'A',N'DEMO-A'),(N'B',N'DEMO-B'),(N'C',N'DEMO-C'),(N'D',N'DEMO-D'),(N'E',N'DEMO-E')) r(RouteCode,WhsCode)
   WHERE NOT EXISTS (SELECT 1 FROM dbo.VM_Routes x WHERE x.RouteCode=r.RouteCode AND x.WhsCode=r.WhsCode)
 )
 THROW 51010, 'Primero ejecute 003; las rutas demo no existen o no coinciden con sus almacenes.', 1;

 DECLARE @customers TABLE(CardCode nvarchar(30),CardName nvarchar(150),PriceListNum int);
 INSERT @customers VALUES
 (N'DEMO-C001',N'Abarrotes La Esquina (DEMO)',1),
 (N'DEMO-C002',N'Minisuper Los Pinos (DEMO)',1),
 (N'DEMO-C003',N'Mercado Central (DEMO)',2),
 (N'DEMO-C004',N'Tienda El Sol (DEMO)',1),
 (N'DEMO-C005',N'Comercializadora Norte (DEMO)',2),
 (N'DEMO-C006',N'Abarrotes Las Flores (DEMO)',1),
 (N'DEMO-C007',N'Minisuper Reforma (DEMO)',2),
 (N'DEMO-C008',N'Tienda San Miguel (DEMO)',1),
 (N'DEMO-C009',N'Distribuidora Oriente (DEMO)',2),
 (N'DEMO-C010',N'Mercadito Familiar (DEMO)',1);

 INSERT dbo.VM_Customers(CardCode,CardName,PriceListNum,IsActive,UpdatedAtUtc)
 SELECT c.CardCode,c.CardName,c.PriceListNum,1,SYSUTCDATETIME()
 FROM @customers c WHERE NOT EXISTS(SELECT 1 FROM dbo.VM_Customers x WHERE x.CardCode=c.CardCode);

 INSERT dbo.VM_CustomerAddresses(CardCode,AddressCode,AddressName,AddressText,IsActive)
 SELECT c.CardCode,N'DEMO-ENTREGA',N'Domicilio de prueba',
        CONCAT(N'Direccion ficticia para ',c.CardCode,N' - NO USAR PARA ENTREGAS'),1
 FROM @customers c WHERE NOT EXISTS(
   SELECT 1 FROM dbo.VM_CustomerAddresses x
   WHERE x.CardCode=c.CardCode AND x.AddressCode=N'DEMO-ENTREGA');

 DECLARE @items TABLE(ItemCode nvarchar(50),ItemName nvarchar(150));
 INSERT @items VALUES
 (N'DEMO-PT001',N'Producto demostracion pollo'),
 (N'DEMO-PT002',N'Producto demostracion res'),
 (N'DEMO-PT003',N'Producto demostracion cerdo'),
 (N'DEMO-PT004',N'Producto demostracion embutido'),
 (N'DEMO-PT005',N'Producto demostracion surtido'),
 (N'DEMO-PT006',N'Producto demostracion especial');

 INSERT dbo.VM_Items(ItemCode,ItemName,BatchManaged,IsActive,UpdatedAtUtc)
 SELECT i.ItemCode,i.ItemName,1,1,SYSUTCDATETIME()
 FROM @items i WHERE NOT EXISTS(SELECT 1 FROM dbo.VM_Items x WHERE x.ItemCode=i.ItemCode);

 DECLARE @routes TABLE(RouteCode nvarchar(30),WhsCode nvarchar(20),Ordinal int);
 INSERT @routes VALUES (N'A',N'DEMO-A',1),(N'B',N'DEMO-B',2),
                       (N'C',N'DEMO-C',3),(N'D',N'DEMO-D',4),(N'E',N'DEMO-E',5);

 ;WITH CustomerNumber AS (
 SELECT CardCode,ROW_NUMBER() OVER(ORDER BY CardCode) AS rn FROM @customers
 )
 INSERT dbo.VM_RouteCustomers(RouteCode,CardCode)
 SELECT r.RouteCode,c.CardCode FROM @routes r
 JOIN CustomerNumber c ON c.rn IN (r.Ordinal*2-1,r.Ordinal*2)
 WHERE NOT EXISTS(SELECT 1 FROM dbo.VM_RouteCustomers x WHERE x.RouteCode=r.RouteCode AND x.CardCode=c.CardCode);

 INSERT dbo.VM_RouteCustomerAddresses(RouteCode,CardCode,AddressCode)
 SELECT rc.RouteCode,rc.CardCode,N'DEMO-ENTREGA'
 FROM dbo.VM_RouteCustomers rc
 JOIN @customers c ON c.CardCode=rc.CardCode
 JOIN @routes r ON r.RouteCode=rc.RouteCode
 WHERE NOT EXISTS(SELECT 1 FROM dbo.VM_RouteCustomerAddresses x
   WHERE x.RouteCode=rc.RouteCode AND x.CardCode=rc.CardCode AND x.AddressCode=N'DEMO-ENTREGA');

 /* Dos lotes por articulo y almacen; cantidades deterministas para pruebas reproducibles. */
 ;WITH Batches AS (
 SELECT r.WhsCode,i.ItemCode,
        CONCAT(N'DEMO-',r.RouteCode,N'-',RIGHT(i.ItemCode,3),N'-L',v.BatchIndex) AS BatchNumber,
        CAST(CASE WHEN v.BatchIndex=1 THEN 250.000 ELSE 125.000 END AS decimal(18,3)) AS AvailableKg
 FROM @routes r CROSS JOIN @items i CROSS JOIN (VALUES(1),(2)) v(BatchIndex)
 )
 INSERT dbo.VM_InventoryBatches(WhsCode,ItemCode,BatchNumber,AvailableKg,UpdatedAtUtc)
 SELECT b.WhsCode,b.ItemCode,b.BatchNumber,b.AvailableKg,SYSUTCDATETIME()
 FROM Batches b
 WHERE NOT EXISTS(SELECT 1 FROM dbo.VM_InventoryBatches x
 WHERE x.WhsCode=b.WhsCode AND x.ItemCode=b.ItemCode AND x.BatchNumber=b.BatchNumber);

 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO

SELECT 'VM_Customers' AS Tabla,COUNT(*) AS RegistrosDemo FROM dbo.VM_Customers WHERE CardCode LIKE N'DEMO-%'
UNION ALL SELECT 'VM_CustomerAddresses',COUNT(*) FROM dbo.VM_CustomerAddresses WHERE CardCode LIKE N'DEMO-%'
UNION ALL SELECT 'VM_Items',COUNT(*) FROM dbo.VM_Items WHERE ItemCode LIKE N'DEMO-%'
UNION ALL SELECT 'VM_InventoryBatches',COUNT(*) FROM dbo.VM_InventoryBatches WHERE ItemCode LIKE N'DEMO-%'
UNION ALL SELECT 'VM_RouteCustomers',COUNT(*) FROM dbo.VM_RouteCustomers WHERE CardCode LIKE N'DEMO-%'
UNION ALL SELECT 'VM_RouteCustomerAddresses',COUNT(*) FROM dbo.VM_RouteCustomerAddresses WHERE CardCode LIKE N'DEMO-%';
GO

SELECT r.RouteCode,r.RouteName,r.WhsCode,
       COUNT(DISTINCT rc.CardCode) AS Clientes,
       COUNT(DISTINCT b.BatchNumber) AS Lotes
FROM dbo.VM_Routes r
LEFT JOIN dbo.VM_RouteCustomers rc ON rc.RouteCode=r.RouteCode AND rc.CardCode LIKE N'DEMO-%'
LEFT JOIN dbo.VM_InventoryBatches b ON b.WhsCode=r.WhsCode AND b.ItemCode LIKE N'DEMO-%'
WHERE r.RouteCode IN(N'A',N'B',N'C',N'D',N'E')
GROUP BY r.RouteCode,r.RouteName,r.WhsCode ORDER BY r.RouteCode;
GO
