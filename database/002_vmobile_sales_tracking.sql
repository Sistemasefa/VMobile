/*
VMobileDB - seguimiento de ventas, consecutivos por ruta y bitacora.
Ejecutar en SSMS contra VMobileDB DESPUES de revisar respaldo y esquema.
No modifica la base de datos de SAP.
La asignacion de folios se hace mediante dbo.VM_ReserveTicket, de manera atomica.
*/
USE VMobileDB;
GO

IF OBJECT_ID(N'dbo.VM_RouteTicketCounters',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.VM_RouteTicketCounters(
   RouteCode nvarchar(30) NOT NULL CONSTRAINT PK_VM_RouteTicketCounters PRIMARY KEY,
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
   RouteCode nvarchar(30) NOT NULL,
   TicketNumber bigint NOT NULL,
   CardCode nvarchar(30) NOT NULL,
   CustomerRfc nvarchar(20) NULL,
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
 IF NULLIF(LTRIM(RTRIM(@RouteCode)),N'') IS NULL THROW 51000,'RouteCode obligatorio',1;
 SET @RouteCode = UPPER(LTRIM(RTRIM(@RouteCode)));
 BEGIN TRANSACTION;
 UPDATE dbo.VM_RouteTicketCounters WITH (UPDLOCK, HOLDLOCK)
 SET LastTicket = LastTicket + 1,
     @TicketNumber = LastTicket + 1
 WHERE RouteCode = @RouteCode;
 IF @@ROWCOUNT = 0
 BEGIN
   INSERT dbo.VM_RouteTicketCounters(RouteCode,LastTicket) VALUES(@RouteCode,1);
   SET @TicketNumber = 1;
 END;
 COMMIT TRANSACTION;
END;
GO
