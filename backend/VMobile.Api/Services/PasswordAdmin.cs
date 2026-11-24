using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;

namespace VMobile.Api.Services;

public static class PasswordAdmin
{
    private static string ReadSecret()
    {
        var chars = new List<char>();
        while (true)
        {
            var key = Console.ReadKey(true);
            if (key.Key == ConsoleKey.Enter) { Console.WriteLine(); return new string(chars.ToArray()); }
            if (key.Key == ConsoleKey.Backspace) { if(chars.Count>0) chars.RemoveAt(chars.Count-1); }
            else if (!char.IsControl(key.KeyChar) && chars.Count<256) chars.Add(key.KeyChar);
        }
    }

    public static async Task<int> Run(IConfiguration config, string userName)
    {
        if (Console.IsInputRedirected || string.IsNullOrWhiteSpace(userName) || userName.Length>100)
        { Console.Error.WriteLine("Se requiere una consola interactiva y un usuario valido."); return 1; }
        Console.Write("Nueva contrasena (minimo 12 caracteres): ");
        var password = ReadSecret();
        Console.Write("Confirmar contrasena: ");
        var confirmation = ReadSecret();
        if (password.Length<12 || password!=confirmation)
        { Console.Error.WriteLine("La contrasena no cumple la longitud o no coincide."); return 1; }
        var hash = new PasswordHasher<string>().HashPassword(userName,password);
        await using var db = new SqlConnection(config.GetConnectionString("VMobile") ?? throw new InvalidOperationException("Missing ConnectionStrings:VMobile"));
        await db.OpenAsync();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync();
        await using var cmd = new SqlCommand("""
            SET XACT_ABORT ON;
            DECLARE @id uniqueidentifier;
            SELECT @id=UserId FROM dbo.VM_Users WITH (UPDLOCK,HOLDLOCK) WHERE UserName=@name;
            IF @id IS NULL THROW 51030,'Usuario inexistente',1;
            UPDATE dbo.VM_Users SET PasswordHash=@hash,PasswordChangedAtUtc=SYSUTCDATETIME(),
              FailedLoginCount=0,LockedUntilUtc=NULL WHERE UserId=@id;
            UPDATE dbo.VM_UserSessions SET RevokedAtUtc=SYSUTCDATETIME()
              WHERE UserId=@id AND RevokedAtUtc IS NULL;
            INSERT dbo.VM_AuditEvents(EventId,RouteCode,ActorId,EventType,Details)
              SELECT NEWID(),RouteCode,N'LOCAL_ADMIN',N'PASSWORD_RESET',CONCAT(N'UserId: ',UserId)
              FROM dbo.VM_Users WHERE UserId=@id;
            """,db,tx);
        cmd.Parameters.Add("@name",SqlDbType.NVarChar,100).Value=userName.Trim();
        cmd.Parameters.Add("@hash",SqlDbType.NVarChar,512).Value=hash;
        await cmd.ExecuteNonQueryAsync();
        await tx.CommitAsync();
        Console.WriteLine("Contrasena actualizada; sesiones anteriores revocadas.");
        return 0;
    }
}
