USE master;
GO
IF DB_ID(N'VMobileDB') IS NULL CREATE DATABASE VMobileDB;
GO
USE VMobileDB;
GO
SELECT DB_NAME() AS CurrentDatabase, @@SERVERNAME AS SqlServerInstance;
GO
-- Ejecutar solo en la instancia SQL separada de SAP; luego 001_core.sql.
