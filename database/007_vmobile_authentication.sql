USE VMobileDB;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF COL_LENGTH(N'dbo.VM_Users',N'PasswordHash') IS NULL
  ALTER TABLE dbo.VM_Users ADD PasswordHash nvarchar(512) NULL;
 IF COL_LENGTH(N'dbo.VM_Users',N'PasswordChangedAtUtc') IS NULL
  ALTER TABLE dbo.VM_Users ADD PasswordChangedAtUtc datetime2(3) NULL;
 IF COL_LENGTH(N'dbo.VM_Users',N'FailedLoginCount') IS NULL
  ALTER TABLE dbo.VM_Users ADD FailedLoginCount int NOT NULL CONSTRAINT DF_VM_Users_FailedLoginCount DEFAULT(0);
 IF COL_LENGTH(N'dbo.VM_Users',N'LockedUntilUtc') IS NULL
  ALTER TABLE dbo.VM_Users ADD LockedUntilUtc datetime2(3) NULL;
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.VM_Users') AND name=N'UX_VM_Users_UserName')
  CREATE UNIQUE INDEX UX_VM_Users_UserName ON dbo.VM_Users(UserName);
 IF OBJECT_ID(N'dbo.VM_UserSessions',N'U') IS NULL
 BEGIN
  CREATE TABLE dbo.VM_UserSessions(
   SessionId uniqueidentifier NOT NULL PRIMARY KEY,
   UserId uniqueidentifier NOT NULL REFERENCES dbo.VM_Users(UserId),
   TokenHash binary(32) NOT NULL UNIQUE,
   DeviceName nvarchar(200) NULL,
   CreatedAtUtc datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
   ExpiresAtUtc datetime2(3) NOT NULL,
   RevokedAtUtc datetime2(3) NULL,
   LastSeenAtUtc datetime2(3) NULL,
   CONSTRAINT CK_VM_UserSessions_Expiry CHECK(ExpiresAtUtc>CreatedAtUtc)
  );
  CREATE INDEX IX_VM_UserSessions_User ON dbo.VM_UserSessions(UserId,ExpiresAtUtc);
 END;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
SELECT UserName,RouteCode,IsActive,
 CASE WHEN PasswordHash IS NULL THEN N'PENDIENTE' ELSE N'CONFIGURADA' END AS Contrasena
FROM dbo.VM_Users ORDER BY RouteCode,UserName;
SELECT OBJECT_ID(N'dbo.VM_UserSessions',N'U') AS SessionTableId;
GO
