# Despliegue inicial en servidor Windows 192.168.1.83

Instancia SQL: `.\\webefa`. Base: `VMobileDB`.

1. Verificar que el script SQL utilizado sea el de `VMobileAndroidStarter/database/001_vmobile_schema.sql`. El esquema publicado previamente en GitHub puede ser diferente. **No ejecutar scripts de creación sobre tablas existentes sin comparar estructuras.**
2. Instalar .NET 8 Hosting Bundle en Windows Server (o runtime según modalidad de alojamiento).
3. Crear una identidad de servicio Windows dedicada y otorgar permisos mínimos en VMobileDB. No usar sa.
4. Configurar `ConnectionStrings__VMobile` como variable de entorno del proceso:
   `Server=.\\webefa;Database=VMobileDB;Integrated Security=True;Encrypt=True;TrustServerCertificate=False;`
   La instancia y el certificado deben ser válidos. Si SQL no tiene certificado confiable, configurar TLS correctamente; no deshabilitar validación en producción.
5. No publicar endpoints de pedidos sin autenticación/autorización por usuario y ruta. El repositorio de pedidos es una capa de datos; aún no se expone por HTTP.
6. Publicar la API detrás de HTTPS con certificado confiable y firewall limitado. Los Android usarán HTTPS a la API, nunca conexión directa SQL.
7. Para producción: implementar transacción de cabecera y líneas, idempotencia por ClientOrderId, autorización por ruta, paginación, consulta detalle y auditoría.

## Estado
`OrderRepository` implementa únicamente creación de cabecera y listado (máximo 100). No implementa todavía líneas ni endpoints. No está compilado ni probado contra el servidor.
