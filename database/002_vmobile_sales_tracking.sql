/*
VMobileDB - seguimiento de ventas, consecutivos por ruta y bitacora.
Ejecutar en SSMS contra VMobileDB DESPUES de revisar respaldo y esquema.
No modifica la base de datos de SAP.
La asignacion de folios se hace mediante dbo.VM_ReserveTicket, de manera atomica.
*/
USE VMobileDB;
GO
SET XACT_ABORT ON;
GO
-- Instalacion inicial solamente: no aplicar sobre una version anterior instalada.

IF OBJECT_ID(N'dbo.VM_RouteTicketCounters',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.VM_RouteTicketCounters(
   RouteCode nvarchar(30) NOT NULL CONSTRAINT PK_VM_RouteTicketCounters PRIMARY KEY REFERENCES dbo.VM_Routes(RouteCode),
   LastTicket bigint NOT NULL CONSTRAINT DF_VM_RouteTicketCounters_LastTicket DEFAULT (0),
   CONSTRAINT CK_VM_RouteTicketCounters_LastTicket CHECK(LastTicket >= 0)
 );
END;
GO

IF OBJECT_ID(N'dbo.VM_Sales',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.VM_Sales(
   SaleId uniqueidentifier NOT NULL CONSTRAINT PK_VM_Sales PRIMARY KEY,
   ClientSaleId uniqueidentifier NOT NULL,
   RouteCode nvarchar(30) NOT NULL REFERENCES dbo.VM_Routes(RouteCode),
   TicketNumber bigint NOT NULL,
   CardCode nvarchar(30) NOT NULL REFERENCES dbo.VM_Customers(CardCode),
   WhsCode nvarchar(20) NOT NULL REFERENCES dbo.VM_Warehouses(WhsCode),
   ShipToCode nvarchar(100) NULL,
   CustomerRfc nvarchar(32) NULL,
   ReferenceSap nvarchar(100) NULL,
   Status nvarchar(30) NOT NULL CONSTRAINT DF_VM_Sales_Status DEFAULT N'PENDIENTE',
   CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_VM_Sales_Created DEFAULT SYSUTCDATETIME(),
   UpdatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_VM_Sales_Updated DEFAULT SYSUTCDATETIME(),
   CONSTRAINT UQ_VM_Sales_ClientSaleId UNIQUE(ClientSaleId),
   CONSTRAINT UQ_VM_Sales_RouteTicket UNIQUE(RouteCode,TicketNumber),
   CONSTRAINT CK_VM_Sales_Ticket CHECK(TicketNumber > 0),
   CONSTRAINT CK_VM_Sales_Status CHECK(Status IN(N'PENDIENTE',N'VALIDANDO',N'INCIDENCIA',N'PARCIAL',N'SINCRONIZADA'))
 );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.VM_Sales') AND name=N'UX_VM_Sales_ReferenceSap')
 CREATE UNIQUE INDEX UX_VM_Sales_ReferenceSap ON dbo.VM_Sales(ReferenceSap) WHERE ReferenceSap IS NOT NULL;
GO

IF OBJECT_ID(N'dbo.VM_SaleLines',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.VM_SaleLines(
   SaleLineId uniqueidentifier NOT NULL PRIMARY KEY,
   SaleId uniqueidentifier NOT NULL REFERENCES dbo.VM_Sales(SaleId),
   LineNumber int NOT NULL CHECK(LineNumber > 0),
   ItemCode nvarchar(50) NOT NULL REFERENCES dbo.VM_Items(ItemCode),
   BatchNumber nvarchar(100) NOT NULL,
   Pieces decimal(18,3) NOT NULL CHECK(Pieces >= 0),
   WeightKg decimal(18,3) NOT NULL CHECK(WeightKg > 0),
   PricePerKg decimal(19,6) NOT NULL CHECK(PricePerKg >= 0),
   Classification nvarchar(30) NOT NULL CHECK(Classification IN(N'Venta',N'Promocion')),
   CONSTRAINT UQ_VM_SaleLines_Number UNIQUE(SaleId,LineNumber)
 );
END;
GO

IF OBJECT_ID(N'dbo.VM_SapDocumentLinks',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.VM_SapDocumentLinks(
   LinkId uniqueidentifier NOT NULL CONSTRAINT PK_VM_SapDocumentLinks PRIMARY KEY,
   SaleId uniqueidentifier NOT NULL REFERENCES dbo.VM_Sales(SaleId),
   DocumentType nvarchar(20) NOT NULL,
   SapDocEntry int NOT NULL,
   SapDocNum int NULL,
   CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_VM_SapDocumentLinks_Created DEFAULT SYSUTCDATETIME(),
   CONSTRAINT UQ_VM_SapDocumentLinks_SaleType UNIQUE(SaleId,DocumentType),
   CONSTRAINT UQ_VM_SapDocumentLinks_SapDoc UNIQUE(DocumentType,SapDocEntry),
   CONSTRAINT CK_VM_SapDocumentLinks_Type CHECK(DocumentType IN(N'ENTREGA',N'FACTURA',N'NOTA_CREDITO'))
 );
END;
GO

IF OBJECT_ID(N'dbo.VM_SyncIncidents',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.VM_SyncIncidents(
   IncidentId uniqueidentifier NOT NULL CONSTRAINT PK_VM_SyncIncidents PRIMARY KEY,
   SaleId uniqueidentifier NOT NULL REFERENCES dbo.VM_Sales(SaleId),
   ItemCode nvarchar(50) NULL,
   BatchNumber nvarchar(100) NULL,
   RequestedKg decimal(18,3) NULL,
   AvailableKg decimal(18,3) NULL,
   ErrorCode nvarchar(80) NOT NULL,
   ErrorMessage nvarchar(2000) NOT NULL,
   ResolvedAtUtc datetime2(3) NULL,
   CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_VM_SyncIncidents_Created DEFAULT SYSUTCDATETIME()
 );
 CREATE INDEX IX_VM_SyncIncidents_Sale ON dbo.VM_SyncIncidents(SaleId,CreatedAtUtc DESC);
END;
GO

IF OBJECT_ID(N'dbo.VM_AuditEvents',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.VM_AuditEvents(
   EventId uniqueidentifier NOT NULL CONSTRAINT PK_VM_AuditEvents PRIMARY KEY,
   EventAtUtc datetime2(3) NOT NULL CONSTRAINT DF_VM_AuditEvents_Time DEFAULT SYSUTCDATETIME(),
   RouteCode nvarchar(30) NULL,
   SaleId uniqueidentifier NULL,
   ActorId nvarchar(100) NULL,
   EventType nvarchar(100) NOT NULL,
   Details nvarchar(max) NULL
 );
 CREATE INDEX IX_VM_AuditEvents_Time ON dbo.VM_AuditEvents(EventAtUtc DESC);
END;
GO

CREATE OR ALTER PROCEDURE dbo.VM_ReserveTicket
 @RouteCode nvarchar(30),
 @TicketNumber bigint OUTPUT
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET @TicketNumber = NULL;
 SET @RouteCode = UPPER(LTRIM(RTRIM(@RouteCode)));
 BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM dbo.VM_Routes WITH (UPDLOCK,HOLDLOCK) WHERE RouteCode=@RouteCode AND IsActive=1)
   THROW 51001,'Ruta inexistente o inactiva',1;
 DECLARE @reserved TABLE(TicketNumber bigint);
 UPDATE dbo.VM_RouteTicketCounters WITH (UPDLOCK,HOLDLOCK)
 SET LastTicket=LastTicket+1
 OUTPUT inserted.LastTicket INTO @reserved
 WHERE RouteCode=@RouteCode;
 IF NOT EXISTS(SELECT 1 FROM @reserved)
 BEGIN
   INSERT dbo.VM_RouteTicketCounters(RouteCode,LastTicket) VALUES(@RouteCode,1);
   INSERT @reserved VALUES(1);
 END;
 SELECT @TicketNumber=TicketNumber FROM @reserved;
 COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 SET @TicketNumber=NULL;
 THROW;
 END CATCH;
END;
GO
SELECT name AS Tabla FROM sys.tables WHERE name IN
(N'VM_RouteTicketCounters',N'VM_Sales',N'VM_SaleLines',N'VM_SapDocumentLinks',N'VM_SyncIncidents',N'VM_AuditEvents')
ORDER BY name;
GO
