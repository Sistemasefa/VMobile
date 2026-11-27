# VM-CP-001 — Punto de control VMobile
Consolidado 2026-11-27; últimas pruebas 2026-11-24. Registro histórico basado en la conversación y resultados del operador, no auditoría independiente del servidor.

## Arquitectura y reglas
Android VMobile -> ASP.NET Core 8 -> SQL Server Express VMobileDB independiente de SAP. Integración SAP Business One mediante Service Layer; panel web central pendiente. No mezclar con ITablet.
Un usuario y almacén por ruta; clientes, direcciones y listas de precios asignados por ruta. Sesión persistente segura. Pedidos inicialmente solo VMobile. Ventas: piezas y kg independientes, peso manual, inventario SAP en kg, por lote, una línea de entrega por lote. U_Piezas y Quantity; U_ConProduct identifica venta/promoción (verificar valores exactos SAP). Entrega seguida de factura; regalos facturados a precio completo y nota de crédito inmediata, mismo u otro artículo. Series mediante serieDelibery y mapeo de notas de crédito pendiente. Ticket Bluetooth Sewoo LK-P25II, muestra kg, consecutivo por ruta compartido F/NV. RFC empieza XX -> NV; otro -> F. Referencia al sincronizar, ejemplo F B 4293 VM. Validar lotes y existencias, corregir lote incorrecto primero en SAP, registrar incidencias y evitar duplicados mediante identificador inmutable y enlaces documentales. Entradas, salidas y cambio de lote pendientes. Panel central de rutas, usuarios, asignaciones, sesiones, movimientos, auditoría e incidencias pendiente.

## Infraestructura
Windows Server 2012 R2 Datacenter, SQL Express instancia predeterminada, .NET SDK 8.0.428. API local 127.0.0.1:5080, AllowedHosts localhost, Production. Directorios C:\VMobile\Source\backend\VMobile.Api, C:\VMobile\API, Config, Logs, Backups. Usuario SQL dedicado VMobile_API con permisos limitados de autenticación; no db_owner. No guardar secretos en repositorio. Android Vivo V40 Lite; pedidos locales creados y consultados exitosamente; no romperlos.

## Base de datos
18 tablas: VM_Warehouses, VM_Routes, VM_Users, VM_Customers, VM_CustomerAddresses, VM_RouteCustomers, VM_RouteCustomerAddresses, VM_Items, VM_InventoryBatches, VM_Orders, VM_OrderLines, VM_Sales, VM_SaleLines, VM_RouteTicketCounters, VM_SapDocumentLinks, VM_SyncIncidents, VM_AuditEvents, VM_UserSessions.
Demo: rutas A-E, almacenes DEMO-A a DEMO-E, usuarios demo_ruta_a a demo_ruta_e, 10 clientes, 60 lotes, 10 ventas pendientes sin envío SAP. Contadores de tickets en 2 por ruta tras datos demo. No asumir que los datos demo son producción.

## Código y pruebas
Backend Program.cs, Services/RouteAuth.cs, Services/PasswordAdmin.cs; CLI --set-password. Endpoints /health, /api/auth/login, /api/auth/me, /api/auth/logout. Token aleatorio almacenado como hash, caducidad 30 días, bloqueo tras cinco fallos durante 15 minutos. No hay middleware global de autorización aún. OrderRepository antiguo no expuesto; revisar RouteCode y filtros antes de publicar. Android pedidos locales SQLite; integración API pendiente. Conector SAP inicial no configurado.
Build Release y publish exitosos; /health OK; /api/auth/me sin token 401; conexión SQL directa Open; contraseña demo_ruta_a actualizada con revocación de sesiones. Conflicto puerto 5080 resuelto tras identificar proceso anterior 2492; API arrancó. POST login devolvió 500: System.InvalidOperationException: No se ha inicializado la propiedad ConnectionString, RouteAuth.cs línea 26. API detenida con Ctrl+C según secuencia de prueba; verificar estado al retomar. Último resultado confirmado: [string]::IsNullOrWhiteSpace($env:ConnectionStrings__VMobile) -> True. La variable estaba vacía en esa sesión. No hay evidencia de fallo de contraseña o permisos en login; todavía no se ha completado la prueba integral.

## Reanudación exacta
En PowerShell del servidor, misma ventana para configurar y arrancar. Ejecutar cada bloque por separado (separar instrucciones con punto y coma por problema de pegado).
```powershell
$cred = Get-Credential -UserName "VMobile_API" -Message "Credenciales SQL de VMobile"
$cs = New-Object System.Data.SqlClient.SqlConnectionStringBuilder; $cs["Data Source"] = "localhost"; $cs["Initial Catalog"] = "VMobileDB"; $cs["User ID"] = "VMobile_API"; $cs["Password"] = $cred.GetNetworkCredential().Password; $cs["Encrypt"] = $true; $cs["TrustServerCertificate"] = $true;
$env:ConnectionStrings__VMobile = $cs.ConnectionString
[string]::IsNullOrWhiteSpace($env:ConnectionStrings__VMobile)
```
Esperar False antes de continuar. No imprimir cadena. Verificar puerto libre e identidad de cualquier proceso antes de detenerlo.
```powershell
Set-Location "C:\VMobile\API"
& "C:\Program Files\dotnet\dotnet.exe" VMobile.Api.dll --urls "http://127.0.0.1:5080"
```
Dejar abierta. Segunda ventana:
```powershell
$vendedor = Get-Credential -UserName "demo_ruta_a" -Message "Acceso VMobile Ruta A"
$body = @{userName="demo_ruta_a"; password=$vendedor.GetNetworkCredential().Password; deviceName="PruebaServidor"} | ConvertTo-Json
$login = Invoke-RestMethod -Uri "http://localhost:5080/api/auth/login" -Method Post -ContentType "application/json" -Body $body
$login.user
```
Esperar ruta A, DEMO-A, demo_ruta_a. No imprimir token. Validar /me con bearer, logout y /me posterior 401. Configurar otras rutas solo tras éxito. Limpiar secretos temporales. No recompilar ni recrear DB inicialmente.

## Pendientes y riesgos
Configuración permanente protegida y servicio Windows; HTTPS; revisar soporte/seguridad del sistema operativo antes de exponer API; TrustServerCertificate temporal local sin validación; autorización por ruta en todos los endpoints; consultas clientes/inventarios; pedidos/ventas API; Android; sincronización SAP y estrategia de consecutivos offline aún no decididas; impresión; panel. No abrir firewall ni enviar ventas demo a SAP. No confundir este documento con backup físico, tag o prueba de despliegue.
