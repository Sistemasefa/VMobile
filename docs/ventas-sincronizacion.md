# VMobile - ventas y sincronizacion SAP

## Reglas confirmadas
- Consecutivo de ticket independiente por ruta, compartido entre F y NV.
- RFC que inicia con XX -> NV; otros RFC -> F. La regla comercial se valida contra el RFC del socio de negocios antes de sincronizar.
- Referencia: `F B 4293 VM` o `NV B 4293 VM`. Se escribe en SAP solo durante sincronizacion, en el campo que se definira despues.
- SAP es la fuente oficial de inventario y lotes. La correccion de lote se realiza primero en SAP y luego se concilia en VMobile.
- Si lote/articulo/cantidad no coinciden, conservar venta e incidencia con datos especificos; no crear documento.
- Antes de crear cada documento SAP, verificar si existe; guardar DocEntry de Entrega, Factura y Nota de Credito por separado. Reintentar solo etapas pendientes.
- No confiar solo en ReferenceSap para idempotencia: utilizar ClientSaleId/SaleId y una referencia tecnica de correlacion en SAP cuando se defina.
- Pedidos se conservan separados de ventas y no se sincronizan con SAP en la primera fase.

## Primera entrega de codigo
- `database/002_vmobile_sales_tracking.sql`: tablas de ventas, contador por ruta, vinculos SAP, incidencias, bitacora y procedimiento de reserva atomica.
- `backend/VMobile.Api/Services/SaleReference.cs`: construccion y validacion de referencia.
- Estos componentes aun NO crean facturas ni entregas en SAP. No se ha conectado la app Android al backend.

## Antes de activar en produccion
1. Verificar esquema existente en el servidor y realizar respaldo.
2. Definir asignacion de tickets sin conexion (rangos reservados por dispositivo/ruta o servicio central) y la politica de recuperacion. No asignar folios independientemente en varios dispositivos sin coordinacion.
3. Implementar autenticacion por ruta, sesiones seguras y panel web administrativo.
4. Implementar API transaccional de venta, lineas, lotes, auditoria y estados.
5. Definir campo SAP para referencia, correlacion tecnica, consulta de documentos, validacion de lotes y control de reintentos concurrentes.
6. Integrar impresion Bluetooth Sewoo LK-P25II con SDK compatible, prueba fisica y reimpresion auditada.
7. Confirmar el flujo fiscal de NV y F, asi como la factura/entrega/nota de credito de promociones.

## Nota sobre folios
`VM_ReserveTicket` reserva un numero unico por ruta si se llama en el servidor; un numero reservado puede quedar sin venta si la transaccion posterior falla. El procedimiento no es una solucion offline por si solo. Los folios preexistentes deben conciliarse antes de inicializar contadores.
