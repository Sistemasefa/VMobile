# VMobile

Backend inicial de ventas móviles para SAP Business One 10.0 FP 2208.

Infraestructura confirmada: API ASP.NET Core en servidor Windows SAP; base `VMobileDB` en **instancia SQL Server separada**.

El proyecto se encuentra en fase bootstrap, sin operaciones SAP de escritura habilitadas. El paquete v0.2 completo se entrega en la conversación. Nunca subir credenciales ni desactivar la validación TLS.

Flujo planeado: venta Android offline -> API -> entrega -> factura -> nota de crédito promocional. Inventario SAP en kg, captura manual de piezas y peso, lotes obligatorios.
