using System.Data;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;

namespace VMobile.Api.Services;

public sealed record LoginRequest(string UserName, string Password, string? DeviceName);
public sealed record RouteIdentity(Guid UserId, string UserName, string RouteCode, string WhsCode);
public sealed class RouteAuth(IConfiguration config)
{
    private SqlConnection Connection() => new(config.GetConnectionString("VMobile") ?? throw new InvalidOperationException("Missing VMobile connection string"));
    private static readonly PasswordHasher<string> Hasher = new();
    private static readonly string DummyHash = Hasher.HashPassword("dummy", Convert.ToHexString(RandomNumberGenerator.GetBytes(32)));
    private static byte[] HashToken(string token) => SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(token));
    private static string? Token(HttpRequest request)
    {
        var header = request.Headers.Authorization.ToString();
        return header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) && header.Length == 71 ? header[7..] : null;
    }
    public async Task<IResult> Login(LoginRequest input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.UserName) || input.UserName.Length > 100 || string.IsNullOrEmpty(input.Password) || input.Password.Length > 256 || input.DeviceName?.Length > 200)
            return Results.BadRequest();
        await using var db = Connection();
        await db.OpenAsync(ct);
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(ct);
        await using var read = new SqlCommand("""
            SELECT u.UserId,u.UserName,u.PasswordHash,u.FailedLoginCount,u.LockedUntilUtc,u.RouteCode,r.WhsCode
            FROM dbo.VM_Users u WITH (UPDLOCK,HOLDLOCK)
            JOIN dbo.VM_Routes r ON r.RouteCode=u.RouteCode
            JOIN dbo.VM_Warehouses w ON w.WhsCode=r.WhsCode
            WHERE u.UserName=@name AND u.IsActive=1 AND r.IsActive=1 AND w.IsActive=1
            """,db,tx);
        read.Parameters.Add("@name",SqlDbType.NVarChar,100).Value=input.UserName.Trim();
        Guid id; string name,route,whs; string? hash; int failures; DateTime? locked;
        await using(var reader=await read.ExecuteReaderAsync(ct))
        {
            if(!await reader.ReadAsync(ct))
            {
                Hasher.VerifyHashedPassword("dummy",DummyHash,input.Password);
                return Results.Unauthorized();
            }
            id=reader.GetGuid(0); name=reader.GetString(1); hash=reader.IsDBNull(2)?null:reader.GetString(2);
            failures=reader.GetInt32(3); locked=reader.IsDBNull(4)?null:reader.GetDateTime(4);
            route=reader.GetString(5); whs=reader.GetString(6);
        }
        if(locked>DateTime.UtcNow) return Results.Unauthorized();
        if(locked.HasValue) failures=0;
        var verification=Hasher.VerifyHashedPassword(name,hash??DummyHash,input.Password);
        if(hash is null || verification==PasswordVerificationResult.Failed)
        {
            await using var fail=new SqlCommand("""
                UPDATE dbo.VM_Users SET FailedLoginCount=@count,
                LockedUntilUtc=CASE WHEN @count>=5 THEN DATEADD(minute,15,SYSUTCDATETIME()) ELSE NULL END
                WHERE UserId=@id
                """,db,tx);
            fail.Parameters.Add("@count",SqlDbType.Int).Value=failures+1;
            fail.Parameters.Add("@id",SqlDbType.UniqueIdentifier).Value=id;
            await fail.ExecuteNonQueryAsync(ct); await tx.CommitAsync(ct);
            return Results.Unauthorized();
        }
        var token=Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var expiry=DateTime.UtcNow.AddDays(30);
        await using var save=new SqlCommand("""
            UPDATE dbo.VM_Users SET FailedLoginCount=0,LockedUntilUtc=NULL,PasswordHash=@hash WHERE UserId=@id;
            INSERT dbo.VM_UserSessions(SessionId,UserId,TokenHash,DeviceName,ExpiresAtUtc)
            VALUES(NEWID(),@id,@token,@device,@expiry);
            """,db,tx);
        save.Parameters.Add("@id",SqlDbType.UniqueIdentifier).Value=id;
        save.Parameters.Add("@hash",SqlDbType.NVarChar,512).Value=verification==PasswordVerificationResult.SuccessRehashNeeded?Hasher.HashPassword(name,input.Password):hash;
        save.Parameters.Add("@token",SqlDbType.Binary,32).Value=HashToken(token);
        save.Parameters.Add("@device",SqlDbType.NVarChar,200).Value=(object?)input.DeviceName??DBNull.Value;
        save.Parameters.Add("@expiry",SqlDbType.DateTime2).Value=expiry;
        await save.ExecuteNonQueryAsync(ct); await tx.CommitAsync(ct);
        return Results.Ok(new {token,expiresAtUtc=expiry,user=new RouteIdentity(id,name,route,whs)});
    }
    public async Task<RouteIdentity?> Resolve(HttpRequest request,CancellationToken ct)
    {
        var token=Token(request); if(token is null)return null;
        await using var db=Connection(); await db.OpenAsync(ct);
        await using var cmd=new SqlCommand("""
            SELECT u.UserId,u.UserName,u.RouteCode,r.WhsCode
            FROM dbo.VM_UserSessions s JOIN dbo.VM_Users u ON u.UserId=s.UserId
            JOIN dbo.VM_Routes r ON r.RouteCode=u.RouteCode
            JOIN dbo.VM_Warehouses w ON w.WhsCode=r.WhsCode
            WHERE s.TokenHash=@token AND s.RevokedAtUtc IS NULL AND s.ExpiresAtUtc>SYSUTCDATETIME()
            AND u.IsActive=1 AND r.IsActive=1 AND w.IsActive=1
            """,db);
        cmd.Parameters.Add("@token",SqlDbType.Binary,32).Value=HashToken(token);
        await using var reader=await cmd.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct)?new RouteIdentity(reader.GetGuid(0),reader.GetString(1),reader.GetString(2),reader.GetString(3)):null;
    }
    public async Task<IResult> Logout(HttpRequest request,CancellationToken ct)
    {
        var token=Token(request); if(token is null)return Results.Unauthorized();
        await using var db=Connection(); await db.OpenAsync(ct);
        await using var cmd=new SqlCommand("UPDATE dbo.VM_UserSessions SET RevokedAtUtc=SYSUTCDATETIME() WHERE TokenHash=@token AND RevokedAtUtc IS NULL",db);
        cmd.Parameters.Add("@token",SqlDbType.Binary,32).Value=HashToken(token);
        await cmd.ExecuteNonQueryAsync(ct); return Results.NoContent();
    }
}
