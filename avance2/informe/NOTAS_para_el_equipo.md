# Notas para el equipo — informe Avance 2 (no pegar en el informe)

## 1. Cómo usar `informe_avance2_texto.md`
- Está redactado en tercera persona y sigue la plantilla: 1 Introducción, 2 Objetivos, 3 Desarrollo (con 3.1 y 3.2), 4 Conclusiones, 5 Bibliografía.
- Las líneas entre corchetes `[Figura N. …]` son los lugares donde va una captura. Reemplazarlas por la imagen y dejar el texto como pie de figura.
- Para pegarlo en Google Docs: abrir el `.md`, copiar todo y usar **Editar → Pegar desde Markdown** (si no aparece: *Herramientas → Preferencias → Habilitar Markdown*). Las tablas quedan como tablas de Docs.
- El texto ya reemplaza al borrador de las secciones 3, 4 y 5 del Doc. La introducción y los objetivos se mantuvieron muy cerca de lo que ya estaba escrito.

## 2. Diferencias entre el borrador del Google Doc y lo que realmente se construyó
El borrador describía un ETL ligeramente distinto al implementado. Todo lo siguiente ya está corregido en `informe_avance2_texto.md`, pero conviene que el equipo lo sepa para la exposición:

| Borrador del Doc | Lo implementado | Qué decir si preguntan |
|---|---|---|
| Tablas `Orders`, `Order Details`, `Customers`, `Employees`, `Products`, `Suppliers`, `Categories`, `Shippers` | Las tablas reales son `Ordenes`, `DetalleOrden`, `Clientes`, `Empleados`, `Productos`, `Proveedores`, `Categorias`, `Transportistas` (+ `Territorios`, `TerritoriosEmpleados`, `Regiones`) | — |
| Transformaciones **Data Conversion**, **Lookup** y **Derived Column** | No se usan esos componentes. Las transformaciones están en la consulta SQL del *OLE DB Source* (CAST, RTRIM, DATEDIFF, cálculo de `monto_neto`, generación de `FechaKey`) y la clave sustituta de cliente se resuelve con un JOIN a `Dim_Cliente` | Es el mismo patrón del ejemplo del profesor (*OLE DB Source con SQL preparado*, clase S08) |
| "Cada flujo inicia limpiando la tabla destino con una Execute SQL Task" | Una sola tarea `00_Limpiar_STAGE` al inicio del paquete 01 vacía las 7 tablas | Equivale a Truncate & Load |
| "cálculo preciso de las ventas **y márgenes**" (conclusiones) | Los márgenes **no se pueden calcular**: `Productos` no tiene costo | El modelo mide ingresos, no rentabilidad |
| "Un empleado con varios territorios duplica las ventas" (relación muchos a muchos) | Verificado con el perfilamiento: cada territorio tiene **un solo** empleado (49 de 49) y cada empleado cubre varios (2 a 10): relación uno-a-muchos. El efecto de duplicación es el mismo | — |
| Dimensiones en estrella con claves naturales | `Dim_Cliente` ahora tiene clave sustituta `ClienteID` + `ClienteCodigo` (la clave real del origen es alfanumérica) | Corrección al modelo del Avance 1 |

## 3. Cosas que NO pude verificar y hay que confirmar
1. **Retroalimentación del Avance 1.** Las dos correcciones (KPI 1 = tiempo de despacho y no de entrega; faltaron las preguntas de negocio) las tomé del borrador del Doc. Confirmar que son lo que realmente dijo el profesor y, si hubo más comentarios, agregarlos en "Correcciones derivadas de la retroalimentación".
2. **Cambio de `Dim_Cliente`.** Es una corrección al modelo que descubrí al construir la carga. Si el profesor ya había pedido otra solución, cambiarlo es sencillo (afecta `avance2/sql/01_correcciones_modelo_DW.sql` y dos consultas del paquete 02).
3. **Territorio.** Se asigna el menor `TerritorioID` por empleado y se declara como limitación. La alternativa más completa (tabla puente con factor de ponderación) no se implementó por tiempo.
4. **Historia de cambios** del informe: agregar una fila por quien escribió o revisó cada sección.

## 4. Capturas que hay que tomar (en este orden)
Preparar el entorno limpio: `powershell -ExecutionPolicy Bypass -File avance2\preparar_entorno.ps1 -RecrearDW` (deja DW y Stage vacíos).

| Figura | Qué mostrar | Cómo obtenerla |
|---|---|---|
| 1 | Data Profile Viewer con el perfil de nulos de `Ordenes` | Abrir `DataProfileViewer.exe` (en `C:\Program Files (x86)\Microsoft SQL Server\150\DTS\Binn\`) → Open → `avance2\ssis\KentFoods_Profiler\Resultados\ORDENES_Profile.xml` → *Column Null Ratio Profile* → `FechaEnvio` (21 nulos) |
| 2 | Control Flow del paquete 01 ejecutado, todo en verde | Abrir `avance2\ssis\KentFoods_ETL_SSIS.sln` en Visual Studio 2019 → doble clic en `01_ETL_KentFoods_OLTP_Stage.dtsx` → F5 |
| 3 | Data Flow `07_DFT_DETALLE` (Source → Destination) | En el paquete 01, doble clic en `07_DFT_DETALLE`; opcionalmente abrir el *OLE DB Source* para mostrar la consulta |
| 4 | Resultado de `SP_CONTROL_STAGE` | SSMS: `EXEC KentFoods_STAGE.dbo.SP_CONTROL_STAGE;` |
| 5 | Control Flow del paquete 02 ejecutado, todo en verde | Abrir `02_ETL_KentFoods_Stage_DW.dtsx` → F5 |
| 6 | Data Flow `13_DFT_Fact_Ventas_Nuevas` | Doble clic en la tarea; mostrar el conteo de filas junto a la flecha (2.155) |
| 7 | Resultado de `SP_CONTROL_DW` | SSMS: `EXEC KentFoods_DW.dbo.SP_CONTROL_DW;` |
| 8 | Segunda ejecución del paquete 02 con 0 filas nuevas | Ejecutar el paquete 02 otra vez; en `13_DFT_Fact_Ventas_Nuevas` el contador muestra 0 |
| 9 | KPI 1 sobre el DW | SSMS: bloque G de `avance2\demo\03_consultas_demo.sql` |

Las figuras 2 y 5 deben mostrar los nombres de las tareas legibles (maximizar el panel). La captura de la ejecución exitosa son los iconos verdes con ✔.

## 4b. Si Visual Studio muestra advertencias
- *"Could not open global shared memory to communicate with performance DLL"*: es un aviso de permisos de Windows, no del paquete. Se evita abriendo Visual Studio como administrador.
- Las conexiones usan `Data Source=.` (instancia local por defecto) y autenticación de Windows; no requieren cambios si las bases se llaman `KentFoods`, `KentFoods_STAGE` y `KentFoods_DW`.
- El proyecto de perfilamiento guarda los XML en una ruta absoluta de esta máquina. En otro computador, ajustar la ruta de los archivos `*_Profile.xml` en *Connection Managers*.
