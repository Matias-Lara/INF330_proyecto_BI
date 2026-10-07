# 1. INTRODUCCIÓN

La organización dispone de una base de datos transaccional (`KentFoods`) que registra órdenes, detalle de órdenes, clientes, empleados, transportistas, proveedores, productos, categorías y territorios. En este segundo avance se construye el proceso de extracción, transformación y carga (ETL) que traslada esos datos hacia un área de Stage y, desde ella, al Data Warehouse diseñado en el Avance 1, manteniendo la granularidad de una fila por línea de producto dentro de una orden.

La metodología se organiza en tres etapas. Primero, el perfilamiento de las fuentes con el Data Profiling Task de SSIS, que permite conocer nulos, tipos, longitudes y claves antes de diseñar las transformaciones. Segundo, un paquete SSIS que extrae las tablas del origen y las deja depuradas en el área de Stage mediante una carga completa. Tercero, un segundo paquete que carga el Data Warehouse: actualiza las dimensiones existentes, inserta las nuevas y agrega únicamente los hechos que aún no existen. Cada etapa se valida con recuentos, totales de control, controles de integridad referencial y consultas sobre los KPI. El desarrollo se realizó con Visual Studio 2019 e Integration Services sobre SQL Server 2019.

# 2. OBJETIVOS DEL PROYECTO

**Objetivo principal:** desarrollar e implementar el proceso ETL que relaciona la base transaccional de Kent Foods con el área de Stage y el Data Warehouse, asegurando trazabilidad entre fuentes, reglas de negocio, modelo dimensional y KPI.

**Objetivos específicos:**

- Caracterizar las fuentes necesarias para responder a los 5 KPI y perfilar los datos con el Data Profiling Task para identificar anomalías (nulos, duplicados, tipos y formatos) que condicionan la carga.
- Diseñar e implementar la malla ETL que carga el área de Stage desde la base relacional, incorporando las transformaciones de depuración necesarias.
- Diseñar e implementar la malla ETL que puebla las dimensiones y la tabla de hechos del Data Warehouse, aplicando las reglas de negocio y las correcciones derivadas del Avance 1.
- Validar las cargas Relacional → Stage y Stage → Data Warehouse mediante recuentos, totales de control, integridad referencial y consultas sobre los KPI.

# 3. DESARROLLO

## Entorno y arquitectura

El proceso utiliza tres bases de datos en una misma instancia local de SQL Server 2019 y dos paquetes SSIS construidos en Visual Studio 2019. Todas las conexiones usan el servidor local (`Data Source=.`) con autenticación de Windows.

| Capa | Base de datos | Contenido | Paquete que la carga |
|---|---|---|---|
| Origen (OLTP) | `KentFoods` | 11 tablas transaccionales | — |
| Stage | `KentFoods_STAGE` | 7 tablas `ST_*` sin claves ni restricciones, más `LOG_CARGA` | `01_ETL_KentFoods_OLTP_Stage` |
| Data Warehouse | `KentFoods_DW` | 6 dimensiones y `Fact_Ventas` | `02_ETL_KentFoods_Stage_DW` |

Flujo general: `KentFoods` → paquete 01 → `KentFoods_STAGE` → paquete 02 → `KentFoods_DW`.

Principios de diseño aplicados:

- El Stage conserva las claves naturales del origen y no define claves primarias ni foráneas; se vacía y se recarga completo en cada ejecución (Truncate & Load), de modo que siempre contiene la última fotografía depurada del origen.
- El Data Warehouse se carga en orden de dependencia: primero las dimensiones y luego la tabla de hechos.
- Las dimensiones se actualizan e insertan solo lo nuevo; los hechos se cargan de forma incremental, sin duplicar ventas ya cargadas.
- Cada paquete finaliza con un procedimiento de control (`SP_CONTROL_STAGE` y `SP_CONTROL_DW`) que compara los resultados, los registra en la tabla `LOG_CARGA` y hace fallar el paquete si detecta diferencias.

### Perfilamiento de las fuentes

El perfilamiento se implementó en un proyecto SSIS independiente (`KentFoods_Profiler`) con cinco paquetes que ejecutan el Data Profiling Task sobre las 11 tablas fuente. Cada tabla genera un archivo XML con seis perfiles: razón de nulos, estadísticas de columna, distribución de longitud, distribución de valores, patrones y claves candidatas. Los resultados se revisaron en Data Profile Viewer y se complementaron con consultas SQL de verificación. La siguiente tabla resume los hallazgos y la decisión que cada uno originó en la ETL.

| N° | Hallazgo del perfilamiento | Riesgo para el Data Warehouse | Regla / transformación en el ETL | Prueba de carga |
|---|---|---|---|---|
| 1 | `Ordenes.FechaEnvio` es nula en 21 de 830 órdenes (73 de 2.155 líneas) | Pedidos aún no despachados no tienen fecha de envío ni tiempo de despacho | `id_fecha_envio`, `dias_envio` quedan en NULL; al despacharse la orden, una tarea de actualización completa esos valores. Las órdenes pendientes no se consideran en el KPI 1 | Control "Líneas sin fecha de envío": 73 = 73 |
| 2 | `Clientes.ClienteID` es alfanumérico (`nchar`, por ejemplo `ALFKI`), mientras `Dim_Cliente.ClienteID` y `Fact_Ventas.id_cliente` son `int` | La carga de clientes y de hechos resultaba imposible con el tipo definido en el Avance 1 | `Dim_Cliente` incorpora una clave sustituta `ClienteID` (identidad) y conserva la clave de negocio en `ClienteCodigo` (única); los hechos obtienen la clave sustituta por `ClienteCodigo` | 91 clientes cargados; 0 hechos sin cliente |
| 3 | `DetalleOrden.Descuento` es de tipo `real` (valores como 0,15000001 y 0,0099999998) | Errores de precisión al calcular montos y diferencias entre ejecuciones | `CAST(ROUND(Descuento, 2) AS decimal(5,2))` en la carga a Stage; descuentos entre 0,00 y 0,25 | `monto_neto` recalculado sin diferencias (0 filas mal calculadas) |
| 4 | `Regiones.Region` y `Territorios.Territorio` son `nchar(100)` y todos sus valores traen relleno de espacios (4 de 4 y 53 de 53) | Valores como "Eastern" + espacios dificultan agrupaciones y comparaciones | `RTRIM` y conversión a `varchar(50)` en la carga a Stage | 0 valores con espacios en `Dim_Empleado` |
| 5 | Cada empleado cubre entre 2 y 10 territorios (los 9 cubren más de uno), todos dentro de una única región; cada territorio tiene un solo empleado | Unir ventas con territorios sin deduplicar multiplica las ventas: $6.205.303 frente a los $1.265.793 reales (4,9 veces) | `Dim_Empleado` tiene una fila por empleado: la región es confiable y el territorio se asigna con un criterio explícito (menor `TerritorioID`) | Suma de ventas por región = venta total ($1.265.793) |
| 6 | El precio de `DetalleOrden` difiere del precio vigente en `Productos` en 658 de 2.155 líneas | Usar el precio actual del producto alteraría las ventas históricas | `monto_neto` se calcula con el precio de la línea (precio al momento de la venta) | Venta del DW = venta del origen (diferencia de $0,25 por redondeo de líneas) |
| 7 | Las fechas no incluyen hora, el envío nunca es anterior a la orden y el rango cubre del 04-07-2016 al 06-05-2018; `Dim_Tiempo` no existe en el origen | La dimensión de tiempo debe construirse | Se genera un calendario completo para los años cubiertos (2016-2018, 1.096 días) y `FechaKey` con formato AAAAMMDD | 0 fechas de hechos sin registro en `Dim_Tiempo` |
| 8 | Sin claves duplicadas (`OrdenID`, `ClienteID`, `ProductoID` y la combinación `OrdenID` + `ProductoID`), sin registros huérfanos y con cantidades siempre positivas | No se requieren reglas de rechazo de filas | Se cargan todos los registros (830 órdenes y 2.155 líneas) | Conteos origen = Stage = DW |
| 9 | Los textos Unicode se pueden convertir a `varchar` sin pérdida de caracteres (0 casos no convertibles); 2 de los 91 clientes no registran órdenes | Conversión segura a los tipos del modelo; clientes sin compras no afectan los KPI | Conversión `nvarchar` → `varchar` con `CAST`; los 91 clientes se cargan en `Dim_Cliente` | 91 = 91 |

[Figura 1. Data Profile Viewer sobre `ORDENES_Profile.xml`: perfil de razón de nulos, con 21 valores nulos en `FechaEnvio`]

## 3.1 MALLA ETL PARA POBLAR EL ÁREA DE STAGE

El área de Stage se diseñó como una zona intermedia que desacopla el entorno operacional (OLTP) del Data Warehouse. Permite extraer la información una sola vez, sin afectar el rendimiento de la base transaccional, y realizar allí la depuración y la estandarización de tipos antes de modelar. Las tablas del Stage se crearon según las necesidades del modelo dimensional: no replican mecánicamente el origen, sino que dejan los datos listos para cargarse a cada dimensión y a la tabla de hechos.

| Tabla Stage | Origen | Filas | Destino conceptual |
|---|---|---|---|
| `ST_CLIENTE` | `Clientes` | 91 | `Dim_Cliente` |
| `ST_PROVEEDOR` | `Proveedores` | 29 | `Dim_Proveedor` |
| `ST_TRANSPORTISTA` | `Transportistas` | 3 | `Dim_Transportista` |
| `ST_PRODUCTO` | `Productos` + `Categorias` | 77 | `Dim_Producto`, `Fact_Ventas` |
| `ST_EMPLEADO` | `Empleados` + `TerritoriosEmpleados` + `Territorios` + `Regiones` | 9 | `Dim_Empleado` |
| `ST_ORDEN` | `Ordenes` | 830 | `Dim_Tiempo`, `Fact_Ventas` |
| `ST_DETALLE` | `DetalleOrden` | 2.155 | `Fact_Ventas` |

El paquete `01_ETL_KentFoods_OLTP_Stage` implementa una carga completa (Truncate & Load) con la siguiente secuencia en el Control Flow. Cada tarea Data Flow utiliza un componente OLE DB Source con una consulta SQL preparada, que entrega los datos con los tipos y nombres definitivos, y un componente OLE DB Destination con carga rápida hacia la tabla `ST_*` correspondiente.

| Orden | Tarea | Tipo | Operación y transformación aplicada |
|---|---|---|---|
| 0 | `00_Limpiar_STAGE` | Execute SQL | `TRUNCATE` de las siete tablas `ST_*` antes de la carga |
| 1 | `01_DFT_CLIENTE` | Data Flow | `Clientes` → `ST_CLIENTE`. La clave alfanumérica se renombra `ClienteCodigo`; `LTRIM`/`RTRIM` y conversión Unicode → `varchar` (hallazgos 2 y 9) |
| 2 | `02_DFT_PROVEEDOR` | Data Flow | `Proveedores` → `ST_PROVEEDOR`; depuración de espacios y conversión de tipos |
| 3 | `03_DFT_TRANSPORTISTA` | Data Flow | `Transportistas` → `ST_TRANSPORTISTA`; depuración y conversión de tipos |
| 4 | `04_DFT_PRODUCTO` | Data Flow | `Productos` + `Categorias` → `ST_PRODUCTO`; se incorpora el nombre de la categoría, tal como lo requiere `Dim_Producto` |
| 5 | `05_DFT_EMPLEADO` | Data Flow | Empleados con su territorio y región → `ST_EMPLEADO`; nombre completo, un territorio por empleado (menor `TerritorioID`) y `RTRIM` del relleno de `nchar(100)` (hallazgos 4 y 5) |
| 6 | `06_DFT_ORDEN` | Data Flow | `Ordenes` → `ST_ORDEN`; fechas a tipo `date`, clave de cliente depurada (hallazgos 1 y 7) |
| 7 | `07_DFT_DETALLE` | Data Flow | `DetalleOrden` → `ST_DETALLE`; precio `money` a `decimal(18,2)` y descuento `real` a `decimal(5,2)` con redondeo (hallazgo 3) |
| 8 | `08_SQL_Control_STAGE` | Execute SQL | Ejecuta `SP_CONTROL_STAGE`: compara conteos, unidades y venta total entre origen y Stage, y registra la carga en `LOG_CARGA` |

[Figura 2. Control Flow del paquete `01_ETL_KentFoods_OLTP_Stage` ejecutado con éxito (todas las tareas en verde)]

[Figura 3. Data Flow de `07_DFT_DETALLE`: OLE DB Source con la consulta de transformación y OLE DB Destination hacia `ST_DETALLE`]

**Validación de la carga a Stage.** Tras ejecutar el paquete se comparó el origen con el Stage mediante `SP_CONTROL_STAGE`. Los conteos coinciden en todas las tablas, las unidades vendidas son idénticas y la venta neta calculada en el Stage coincide con la del origen ($1.265.793,04).

| Control | Origen | Stage | Estado |
|---|---|---|---|
| `ST_CLIENTE` | 91 | 91 | OK |
| `ST_PROVEEDOR` | 29 | 29 | OK |
| `ST_TRANSPORTISTA` | 3 | 3 | OK |
| `ST_PRODUCTO` | 77 | 77 | OK |
| `ST_EMPLEADO` | 9 | 9 | OK |
| `ST_ORDEN` | 830 | 830 | OK |
| `ST_DETALLE` | 2.155 | 2.155 | OK |
| Unidades vendidas | 51.317 | 51.317 | OK |
| Venta neta | 1.265.793,04 | 1.265.793,04 | OK |

[Figura 4. Resultado de `EXEC SP_CONTROL_STAGE` en SSMS]

## 3.2 MALLA ETL PARA POBLAR EL DATAWAREHOUSE

Una vez depurados los datos en el Stage, el paquete `02_ETL_KentFoods_Stage_DW` puebla la estructura en estrella del Data Warehouse: las dimensiones `Dim_Tiempo`, `Dim_Transportista`, `Dim_Proveedor`, `Dim_Producto`, `Dim_Cliente` y `Dim_Empleado`, y la tabla de hechos `Fact_Ventas`. Las dimensiones se cargan antes que los hechos para que las claves foráneas siempre tengan su registro asociado.

### Estrategia de carga

- **Dimensiones:** cada una se carga en dos pasos. Una tarea Execute SQL actualiza los registros existentes cuyos atributos cambiaron en el Stage, y una tarea Data Flow inserta solo los registros que aún no existen en el Data Warehouse.
- **Tabla de hechos:** se carga de forma incremental. Solo se insertan las órdenes con identificador mayor al máximo ya cargado (`MAX(id_orden)`), por lo que ejecutar el paquete nuevamente sin cambios en el origen no agrega filas. Se asume que `OrdenID` es creciente, como en el sistema transaccional.
- **Órdenes pendientes de despacho:** una tarea previa completa `id_fecha_envio`, `dias_envio` y `id_transportista` en las líneas que estaban pendientes cuando la orden ya registra su envío.
- **Claves:** las dimensiones conservan la clave natural como clave primaria, salvo `Dim_Cliente`, que usa una clave sustituta (hallazgo 2). `Fact_Ventas` solo almacena claves del Data Warehouse.

| Orden | Tarea | Tipo | Operación |
|---|---|---|---|
| 0 | `00_SQL_Verificar_Precondiciones` | Execute SQL | Verifica que el Stage tenga datos; si está vacío, el paquete falla con un mensaje explícito |
| 1 | `01_DFT_Dim_Tiempo_Nuevas` | Data Flow | Genera el calendario completo de los años cubiertos y carga solo las fechas inexistentes → `Dim_Tiempo` |
| 2–3 | `02_SQL_Actualizar_Dim_Transportista` / `03_DFT_Dim_Transportista_Nuevos` | SQL + Data Flow | Actualiza e inserta → `Dim_Transportista` |
| 4–5 | `04_SQL_Actualizar_Dim_Proveedor` / `05_DFT_Dim_Proveedor_Nuevos` | SQL + Data Flow | Actualiza e inserta → `Dim_Proveedor` |
| 6–7 | `06_SQL_Actualizar_Dim_Producto` / `07_DFT_Dim_Producto_Nuevos` | SQL + Data Flow | Actualiza e inserta → `Dim_Producto` |
| 8–9 | `08_SQL_Actualizar_Dim_Cliente` / `09_DFT_Dim_Cliente_Nuevos` | SQL + Data Flow | Actualiza e inserta por `ClienteCodigo`; SQL Server genera la clave sustituta → `Dim_Cliente` |
| 10–11 | `10_SQL_Actualizar_Dim_Empleado` / `11_DFT_Dim_Empleado_Nuevos` | SQL + Data Flow | Actualiza e inserta → `Dim_Empleado` |
| 12 | `12_SQL_Actualizar_Envios_Pendientes` | Execute SQL | Completa envío, días y transportista de las líneas que estaban pendientes |
| 13 | `13_DFT_Fact_Ventas_Nuevas` | Data Flow | Inserta solo las órdenes nuevas en `Fact_Ventas`, con las transformaciones de la tabla siguiente |
| 14 | `14_SQL_Control_DW` | Execute SQL | Ejecuta `SP_CONTROL_DW` y registra la carga en `LOG_CARGA` |

[Figura 5. Control Flow del paquete `02_ETL_KentFoods_Stage_DW` ejecutado con éxito]

[Figura 6. Data Flow de `13_DFT_Fact_Ventas_Nuevas`: consulta de origen con las transformaciones y destino `Fact_Ventas`]

### Transformaciones y reglas de negocio

| Campo del DW | Transformación | Regla de negocio que la sustenta |
|---|---|---|
| `id_fecha_orden`, `id_fecha_envio` | `CAST(CONVERT(char(8), fecha, 112) AS int)` genera la clave AAAAMMDD que relaciona con `Dim_Tiempo`; es NULL cuando no hay envío | Toda orden tiene fecha; el envío puede estar pendiente (hallazgo 1) |
| `dias_envio` | `DATEDIFF(DAY, FechaOrden, FechaEnvio)`; NULL cuando no hay fecha de envío | El KPI 1 mide el tiempo de despacho (de la orden al envío) y excluye las órdenes pendientes |
| `monto_neto` | `ROUND(PrecioUnitario × Cantidad × (1 − Descuento), 2)` con el precio de la línea | El ingreso de una línea se calcula con el precio y el descuento vigentes al vender (hallazgos 3 y 6) |
| `id_cliente` | Se obtiene la clave sustituta de `Dim_Cliente` a partir de `ClienteCodigo` | Los hechos almacenan claves del Data Warehouse, no claves del sistema operacional (hallazgo 2) |
| `id_proveedor` | Se obtiene desde `ST_PRODUCTO` sin descartar filas | Todo producto tiene un proveedor asociado (hallazgo 8) |
| `Dim_Empleado.Region` y `Territorio` | Una fila por empleado; región desde su territorio y territorio con criterio explícito | Un empleado pertenece a una única región (hallazgo 5) |
| `Dim_Tiempo` | Calendario generado a partir del rango de fechas de las órdenes | La dimensión no existe en el origen (hallazgo 7) |

### Correcciones derivadas de la retroalimentación del Avance 1

**KPI 1: tiempo de despacho.** La retroalimentación del Avance 1 señaló que el KPI 1 confundía el tiempo de despacho interno con el reparto o la entrega final. Se corrigió su definición: el KPI 1 corresponde al tiempo promedio de despacho, es decir, los días entre la emisión de la orden (`FechaOrden`) y su envío (`FechaEnvio`), por transportista y período. El modelo relacional de Kent Foods no registra una fecha de entrega al cliente, por lo que el tiempo de reparto no es medible con los datos disponibles y queda fuera del alcance del indicador. En el ETL, la medida `dias_envio` se calcula como `DATEDIFF(día, FechaOrden, FechaEnvio)` y se mantiene en NULL para las 21 órdenes aún no despachadas. Como el valor se repite en cada línea de una misma orden, el KPI se calcula promediando primero por orden y luego por transportista, evitando ponderar más a las órdenes con más productos.

**Preguntas de negocio.** La retroalimentación también indicó que el Avance 1 omitió la formulación de las preguntas de negocio. Se incorporan a continuación, con la medida de `Fact_Ventas` y las dimensiones que las responden.

| N° | Pregunta de negocio | KPI | Medida | Dimensiones |
|---|---|---|---|---|
| 1 | ¿Cuál es el tiempo promedio de despacho de cada transportista y cómo varía por período? | KPI 1 | `dias_envio` | `Dim_Transportista`, `Dim_Tiempo` |
| 2 | ¿Cómo evolucionan las ventas de cada región respecto del período anterior? | KPI 2 | `monto_neto` | `Dim_Empleado` (región), `Dim_Tiempo` |
| 3 | ¿Qué proveedores generan más ingresos netos? | KPI 3 | `monto_neto` | `Dim_Proveedor` |
| 4 | ¿Cuántas unidades incluye en promedio cada cliente en sus pedidos? | KPI 4 | `cantidad` | `Dim_Cliente` |
| 5 | ¿Qué proporción de las ventas aporta cada categoría de producto? | KPI 5 | `monto_neto` | `Dim_Producto`, `Dim_Tiempo` |

**Clave de `Dim_Cliente`.** Al diseñar la carga se detectó que la clave de cliente del origen es alfanumérica, por lo que `Dim_Cliente` y `Fact_Ventas` no podían almacenarla como `int`. El modelo se corrigió: `ClienteID` pasa a ser una clave sustituta autogenerada y la clave original se conserva en `ClienteCodigo`, con restricción de unicidad. El resto del modelo del Avance 1 se mantiene sin cambios.

### Validación de la carga al Data Warehouse

Tras ejecutar el paquete se ejecutó `SP_CONTROL_DW`, que compara el Stage con el Data Warehouse. Los controles confirman que no hay pérdida ni duplicación de filas, que la venta y las unidades coinciden, que las órdenes pendientes quedan con envío nulo y que no existen hechos sin su dimensión.

| Control | Esperado (Stage) | Obtenido (DW) | Estado |
|---|---|---|---|
| `Dim_Cliente`, `Dim_Proveedor`, `Dim_Transportista`, `Dim_Producto`, `Dim_Empleado` | 91 · 29 · 3 · 77 · 9 | 91 · 29 · 3 · 77 · 9 | OK |
| Líneas en `Fact_Ventas` | 2.155 | 2.155 | OK |
| Unidades vendidas | 51.317 | 51.317 | OK |
| Venta neta | 1.265.793,04 | 1.265.793,29 | OK (diferencia de $0,25 por redondeo de cada línea a 2 decimales) |
| Líneas sin fecha de envío | 73 | 73 | OK |
| Hechos sin `Dim_Tiempo`, `Dim_Cliente`, `Dim_Transportista`, `Dim_Empleado`, `Dim_Proveedor` o `Dim_Producto` | 0 | 0 | OK |

[Figura 7. Resultado de `EXEC SP_CONTROL_DW` en SSMS]

**Prueba de re-ejecución y de carga incremental.** Para verificar la estrategia incremental se ejecutó el paquete 02 dos veces sin cambios en el origen: no se agregó ninguna fila ni se alteraron las dimensiones (2.155 líneas, 91 clientes). Luego se simularon cambios en el origen: se despachó una orden pendiente (11008, con 3 líneas), se registró una orden nueva (2 líneas) y un cliente cambió de ciudad. Tras ejecutar nuevamente ambos paquetes, el Data Warehouse reflejó exactamente esos cambios y los controles siguieron en OK.

| Verificación | Antes | Después | Resultado esperado |
|---|---|---|---|
| Líneas en `Fact_Ventas` | 2.155 | 2.157 | +2 líneas de la orden nueva |
| Órdenes distintas | 830 | 831 | +1 orden |
| Líneas pendientes de envío | 73 | 72 | −3 de la orden despachada, +2 de la orden nueva |
| Clientes en `Dim_Cliente` | 91 | 91 | Sin duplicados |
| Ciudad del cliente modificado | Berlin | Berlin TEST | Atributo actualizado |
| Venta neta | 1.265.793,29 | 1.266.050,29 | +257,00 |

[Figura 8. Segunda ejecución del paquete 02 sin cambios en el origen: el registro de ejecución indica que `DST_Fact_Ventas` escribió 0 filas]

**Consultas sobre los KPI.** Para comprobar que el modelo cargado permite responder las preguntas de negocio se calcularon los cinco KPI directamente sobre el Data Warehouse. Los resultados de los KPI 1 y 5 coinciden con los obtenidos directamente desde el origen (en el KPI 5, con diferencias por redondeo menores a $0,07 por categoría).

| KPI 1: tiempo promedio de despacho | Órdenes despachadas | Promedio (días) |
|---|---|---|
| Federal Shipping | 249 | 7,47 |
| Speedy Express | 245 | 8,57 |
| United Package | 315 | 9,23 |

| KPI 5: categoría | Ventas | % de la venta total |
|---|---|---|
| Beverages | 267.868,20 | 21,16 |
| Dairy Products | 234.507,32 | 18,53 |
| Confections | 167.357,29 | 13,22 |
| Meat/Poultry | 163.022,38 | 12,88 |
| Seafood | 131.261,77 | 10,37 |
| Condiments | 106.047,15 | 8,38 |
| Produce | 99.984,58 | 7,90 |
| Grains/Cereals | 95.744,60 | 7,56 |

Las ventas por región (KPI 2) suman exactamente la venta total del Data Warehouse, sin la duplicación que producía la unión directa con `TerritoriosEmpleados`. El KPI 3 reúne los 29 proveedores con ventas y el KPI 4 entrega el promedio de unidades por pedido para cada uno de los clientes con compras.

[Figura 9. Consulta del KPI 1 sobre el Data Warehouse]

### Limitaciones conocidas

- **Territorio:** como cada empleado cubre entre 2 y 10 territorios y la venta no registra el territorio donde ocurrió, el atributo `Territorio` de `Dim_Empleado` se asigna con un criterio explícito (menor `TerritorioID`) y no debe usarse para analizar ventas por territorio. El análisis por región es confiable. Una mejora futura es una tabla puente entre hechos y territorios con un factor de ponderación.
- **Historia de atributos:** las dimensiones se actualizan sobreescribiendo el valor vigente (sin historial). Ninguno de los cinco KPI requiere conservar versiones anteriores.
- **Margen de ganancia:** el origen no registra el costo de los productos, por lo que el modelo mide ingresos y no rentabilidad.
- **Entrega al cliente:** el origen no registra la fecha de entrega, por lo que solo se mide el tiempo de despacho.

# 4. CONCLUSIONES

El desarrollo del proceso ETL permitió trasladar los datos del sistema transaccional de Kent Foods hacia un área de Stage y, finalmente, al Data Warehouse, comprobando en cada etapa que no hubo pérdida ni duplicación de información. La separación en dos paquetes facilita las pruebas, la trazabilidad y el mantenimiento: el primero reconstruye el Stage por completo en cada ejecución y el segundo carga el modelo dimensional de forma incremental.

Lo más relevante fue que el perfilamiento previo determinó las transformaciones. Hallazgos como la clave de cliente alfanumérica, el descuento almacenado como número de punto flotante, el relleno de espacios en región y territorio, las 21 órdenes sin fecha de envío y la duplicación de ventas al unir por territorios orientaron decisiones concretas que se verificaron con controles de carga. Las correcciones derivadas del Avance 1 permitieron precisar el KPI 1 como tiempo de despacho, incorporar las preguntas de negocio y corregir la clave de `Dim_Cliente`.

Como trabajo futuro se proyectan la automatización programada de los paquetes mediante SQL Server Agent, la incorporación de una tabla puente para el análisis por territorio, la construcción de cubos OLAP relacionados con los KPI y el diseño de un dashboard en Power BI para la toma de decisiones directivas.

# 5. BIBLIOGRAFÍA

- Figueroa Colarte, M. (2026). *Caso Semestral Forma C – KentFoods*. Universidad Técnica Federico Santa María, Departamento de Informática.
- Figueroa Colarte, M. (2026). *Introducción a procesos ETL; Perfilamiento de datos antes de la primera carga del DW; Diseño ETL VENTAS con SSIS* [Material de clases, INF330 Bases Tecnológicas para la Inteligencia de Negocios]. Universidad Técnica Federico Santa María.
- Kimball, R., & Ross, M. (2013). *The Data Warehouse Toolkit: The Definitive Guide to Dimensional Modeling* (3.ª ed.). John Wiley & Sons.
- Microsoft. (2023). *SQL Server Integration Services (SSIS) documentation*. Microsoft Learn.
- Microsoft. (2023). *Data Profiling Task and Viewer*. Microsoft Learn.
- Rainardi, V. (2008). *Building a Data Warehouse: With Examples in SQL Server*. Apress.
