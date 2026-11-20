/*
VMobile DEMO - Fase 1
Datos ficticios para almacenes, rutas y usuarios.
No ejecuta integracion SAP. No crea contrasenas ni habilita autenticacion.
Idempotente: puede ejecutarse nuevamente sin duplicar registros de esta fase.
Antes de ejecutar, hacer respaldo y verificar que las tablas esten vacias.
*/
USE VMobileDB;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;

 DECLARE @wh TABLE(WhsCode nvarchar(20), WhsName nvarchar(150));
 INSERT INTO @wh VALUES
 (N'DEMO-A',N'Almacen demostracion Ruta A'),
 (N'DEMO-B',N'Almacen demostracion Ruta B'),
 (N'DEMO-C',N'Almacen demostracion Ruta C'),
 (N'DEMO-D',N'Almacen demostracion Ruta D'),
 (N'DEMO-E',N'Almacen demostracion Ruta E');

 INSERT INTO dbo.VM_Warehouses(WhsCode,WhsName,IsActive,UpdatedAtUtc)
 SELECT w.WhsCode,w.WhsName,1,SYSUTCDATETIME()
 FROM @wh w WHERE NOT EXISTS(SELECT 1 FROM dbo.VM_Warehouses x WHERE x.WhsCode=w.WhsCode);

 DECLARE @routes TABLE(RouteCode nvarchar(30),RouteName nvarchar(150),WhsCode nvarchar(20));
 INSERT INTO @routes VALUES
 (N'A',N'Ruta A',N'DEMO-A'),
 (N'B',N'Ruta B',N'DEMO-B'),
 (N'C',N'Ruta C',N'DEMO-C'),
 (N'D',N'Ruta D',N'DEMO-D'),
 (N'E',N'Ruta E',N'DEMO-E');

 INSERT INTO dbo.VM_Routes(RouteCode,RouteName,WhsCode,IsActive)
 SELECT r.RouteCode,r.RouteName,r.WhsCode,1
 FROM @routes r WHERE NOT EXISTS(SELECT 1 FROM dbo.VM_Routes x WHERE x.RouteCode=r.RouteCode);

 DECLARE @users TABLE(UserName nvarchar(100),DisplayName nvarchar(150),RouteCode nvarchar(30));
 INSERT INTO @users VALUES
 (N'demo_ruta_a',N'Vendedor demostracion A',N'A'),
 (N'demo_ruta_b',N'Vendedor demostracion B',N'B'),
 (N'demo_ruta_c',N'Vendedor demostracion C',N'C'),
 (N'demo_ruta_d',N'Vendedor demostracion D',N'D'),
 (N'demo_ruta_e',N'Vendedor demostracion E',N'E');

 INSERT INTO dbo.VM_Users(UserId,UserName,DisplayName,RouteCode,IsActive)
 SELECT NEWID(),u.UserName,u.DisplayName,u.RouteCode,1
 FROM @users u WHERE NOT EXISTS(SELECT 1 FROM dbo.VM_Users x WHERE x.UserName=u.UserName);

 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
SELECT 'VM_Warehouses' AS Tabla,COUNT(*) AS Registros FROM dbo.VM_Warehouses
UNION ALL SELECT 'VM_Routes',COUNT(*) FROM dbo.VM_Routes
UNION ALL SELECT 'VM_Users',COUNT(*) FROM dbo.VM_Users;
GO

/* Para preparar fase 2, obtener columnas de las cinco tablas pendientes: */
SELECT t.name AS Tabla,c.column_id AS Posicion,c.name AS Columna,
 TYPE_NAME(c.user_type_id) AS TipoDato,c.max_length AS Longitud,
 c.is_nullable AS PermiteNulos,c.is_identity AS EsIdentidad,
 dc.definition AS ValorPredeterminado
FROM sys.tables t
JOIN sys.columns c ON c.object_id=t.object_id
LEFT JOIN sys.default_constraints dc ON dc.object_id=c.default_object_id
WHERE t.name IN (N'VM_Customers',N'VM_CustomerAddresses',N'VM_Items',
                 N'VM_RouteCustomers',N'VM_RouteCustomerAddresses')
ORDER BY t.name,c.column_id;
GO
