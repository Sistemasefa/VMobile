/* VMobileDB: ejecutar en 192.168.1.83\webefa con SSMS. No modifica SAP. */
IF DB_ID(N'VMobileDB') IS NULL CREATE DATABASE VMobileDB;
GO
USE VMobileDB;
GO
IF OBJECT_ID(N'dbo.VM_Orders',N'U') IS NULL
CREATE TABLE dbo.VM_Orders (
 OrderId uniqueidentifier NOT NULL PRIMARY KEY,
 ClientOrderId uniqueidentifier NOT NULL UNIQUE,
 CardCode nvarchar(30) NOT NULL,
 RouteCode nvarchar(30) NOT NULL,
 ShipToCode nvarchar(100) NULL,
 Status nvarchar(20) NOT NULL DEFAULT N'BORRADOR',
 Notes nvarchar(1000) NULL,
 CreatedAtUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_VM_Orders_Status CHECK (Status IN (N'BORRADOR',N'CONFIRMADO',N'CANCELADO'))
);
GO
IF OBJECT_ID(N'dbo.VM_OrderLines',N'U') IS NULL
CREATE TABLE dbo.VM_OrderLines (
 OrderLineId uniqueidentifier NOT NULL PRIMARY KEY,
 OrderId uniqueidentifier NOT NULL REFERENCES dbo.VM_Orders(OrderId),
 LineNumber int NOT NULL,
 ItemCode nvarchar(50) NOT NULL,
 Pieces decimal(18,3) NOT NULL CHECK (Pieces>0),
 WeightKg decimal(18,3) NOT NULL CHECK (WeightKg>0),
 PricePerKg decimal(19,6) NULL,
 Classification nvarchar(30) NOT NULL CHECK (Classification IN (N'Venta',N'Promocion')),
 CONSTRAINT UQ_VM_OrderLines UNIQUE(OrderId,LineNumber)
);
GO
IF OBJECT_ID(N'dbo.VM_OrderBatchAllocations',N'U') IS NULL
CREATE TABLE dbo.VM_OrderBatchAllocations (
 AllocationId uniqueidentifier NOT NULL PRIMARY KEY,
 OrderLineId uniqueidentifier NOT NULL REFERENCES dbo.VM_OrderLines(OrderLineId),
 BatchNumber nvarchar(100) NOT NULL,
 Pieces decimal(18,3) NOT NULL CHECK(Pieces>0),
 WeightKg decimal(18,3) NOT NULL CHECK(WeightKg>0)
);
GO
IF OBJECT_ID(N'dbo.VM_DocumentSeries',N'U') IS NULL
CREATE TABLE dbo.VM_DocumentSeries (
 CommercialSeriesName nvarchar(100) NOT NULL PRIMARY KEY,
 DeliverySeries int NOT NULL,
 InvoiceSeries int NOT NULL,
 CreditNoteSeries int NOT NULL
);
GO
