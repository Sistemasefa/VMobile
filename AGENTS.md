# VMobile — instrucciones de trabajo
- Trabajar exclusivamente en Sistemasefa/VMobile; no mezclar ITablet.
- Antes de modificar código, leer docs/checkpoints/VM-CP-001.md y los puntos de control posteriores, si existen. Contrastar con el código y los resultados reales; el checkpoint no sustituye pruebas.
- Respetar las reglas de negocio acordadas. Consultar al usuario ante ambigüedades materiales; no inventar datos ni resultados.
- Preservar pedidos locales Android y funcionalidades probadas. Cambios pequeños, verificables; distinguir desarrollado, compilado, desplegado y probado.
- No almacenar contraseñas, cadenas con secretos ni tokens. No exponer API, cambiar firewall, enviar datos demo a SAP ni ejecutar operaciones destructivas sin autorización.
- Validar identidad y permisos por ruta en servidor; no confiar en la ruta enviada por el cliente.
- Dar instrucciones en español, paso a paso, compatibles con Windows PowerShell del servidor; separar comandos con punto y coma si se copian juntos.
- Al retomar VM-CP-001, primero resolver configuración temporal de conexión SQL y probar autenticación ruta A. No recrear base de datos ni recompilar sin necesidad.
- Registrar nuevos checkpoints al cerrar etapas, incluyendo pruebas reales, bloqueos, decisiones y próximo paso. No afirmar que un commit equivale a despliegue.
