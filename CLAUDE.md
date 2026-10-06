# INF330 — Proyecto BI Kent Foods (Grupo 7)

## Contexto
- Curso: INF330 – Bases Tecnológicas para la Inteligencia de Negocios (UTFSM). Docente: Mauricio Figueroa.
- Caso: Kent Foods (Caso Semestral Forma C) — venta de alimentos por envíos.
- Proceso de negocio: **Gestión de Ventas y Envíos** (desde la orden hasta la entrega).
- **Entrega actual: Avance 2 — Proceso ETL** (SSIS en Visual Studio 2019). Avance 1 (modelo dimensional) ya fue entregado.
- **Presentación Avance 2: miércoles 7 de octubre de 2026, 11:20–11:35** (10 min exposición + demo en vivo de la ETL, 5 min preguntas).
- Proyecto semestral completo: modelo dimensional → ETL (SSIS) → cubos OLAP / modelo semántico en Power BI → Dashboard.
- Los informes se redactan en un doc en el navegador (no en el repo). Los PDF locales son exports/snapshots: revisar el timestamp antes de asumir que algo no cambió.

## Estructura del repo
- `bd/` — `KentFoods.bak` (BD relacional fuente, esquema Northwind) y `KentFoods_DW.bak` (DW dimensional **original del Avance 1**; solo esquema, 0 filas; sin la corrección de `Dim_Cliente`).
- `material_curso/` — `Caso_Semestral_FormaC.pdf` (caso + reglas de formato del informe: tercera persona, Calibri 11, máx. 50 págs., 6 secciones) y el manual de instalación del entorno (Visual Studio/SSIS/SQL Server).
- `ppts/` — clases del profesor (S03 a S08: DW, modelo multidimensional, ETL, perfilamiento, diseño ETL VENTAS con SSIS). `ejemplos_profesor/` — caso VENTAS resuelto: bases `.bak`, proyecto SSIS `ETL_VENTAS.zip`, perfilador `VENTAS_OLTP_Profiler.zip` y scripts. **Es el patrón que el profesor espera** (Stage FULL, DW incremental, claves sustitutas, SP de control, perfilamiento con Data Profiling Task).
- `instrucciones_avance1/` — plantilla, rúbrica e instrucciones del Avance 1 (ya entregado).
- `entrega_avance1_oficial/` — informe y PPT **tal como se subieron al aula virtual**. Ver `NOTA_seccion_faltante.md`.
- `instrucciones_avance2/` — plantilla del informe 2 (`.docx`), rúbrica (`.xlsx`) e instrucciones del buzón.
- **`avance2/`** — todo el trabajo del Avance 2 (ver "Estado del Avance 2"): `sql/`, `ssis/`, `evidencias/`, `demo/`, `informe/`, `respaldos/`, `herramientas/`, `PROGRESO.md`, `preparar_entorno.ps1`, `ejecutar_etl.ps1`.
- El historial de git conserva el borrador del informe 1, la PPT anterior y el brief de la PPT (commit `cb322fd`).

## Estado del Avance 2 (06-10-2026) — leer `avance2/PROGRESO.md`
- **Hecho y verificado:** bases `KentFoods` / `KentFoods_STAGE` / `KentFoods_DW` (archivos en `E:\SQLData`), perfilamiento (Data Profiling Task + SQL), paquetes SSIS `01_ETL_KentFoods_OLTP_Stage` y `02_ETL_KentFoods_Stage_DW` (ejecutan con `dtexec`, compilan en VS 2019), controles `SP_CONTROL_STAGE` / `SP_CONTROL_DW`, prueba incremental con cambios reales en el origen (revertidos), respaldos, texto del informe y guion de demo.
- **Pendiente (equipo):** 9 capturas en VS/SSMS, pegar el texto en el Google Doc, diapositivas, ensayar la demo, abrir la solución en VS y ejecutar con F5.
- **Diseño:** Stage completo (Truncate & Load); DW: dimensiones tipo 1 (UPDATE + insertar nuevas), hechos incremental por `MAX(id_orden)`, actualización de envíos pendientes. Transformaciones en el SQL del OLE DB Source (sin Lookup/Derived Column). La generación de paquetes se hace con `avance2/herramientas/generar_paquetes.ps1` (API de SSIS + `DftBuilder.cs`).
- **Corrección al modelo:** `Dim_Cliente.ClienteID` ahora es clave sustituta (IDENTITY) y se agregó `ClienteCodigo` (clave alfanumérica real del origen, única). Aplicada por `avance2/sql/01_correcciones_modelo_DW.sql`.
- **Feedback del Avance 1** (según el borrador del Doc, sin verificar con el profesor): el KPI 1 debe ser tiempo de **despacho** (orden → envío), no de entrega; faltaban las preguntas de negocio. Ya incorporado en el texto del informe.
- **Levantar todo desde cero en otro PC:** `avance2\preparar_entorno.ps1 -RecrearDW` y luego `avance2\ejecutar_etl.ps1` (perfilamiento: `avance2\ejecutar_perfilamiento.ps1`). Detalle y requisitos en `avance2/PROGRESO.md`. La memoria personal de Claude no viaja entre PCs: todo lo importante debe estar en este archivo.
- **Entorno (Windows):** SQL Server 2019 + SSIS en servicio, VS Community 2019 en `E:\Microsoft Visual Studio\2019\Community` con la extensión Integration Services Projects 4.0. Se pueden ejecutar paquetes con `C:\Program Files\Microsoft SQL Server\150\DTS\Binn\DTExec.exe` y compilar con `devenv.com <sln> /Build Development`.

## Rúbrica Avance 2 (100 pts, aprobación 55)
Fuente de verdad: `instrucciones_avance2/02 Rubrica_Avance2_Proceso_ETL.xlsx`.
1. Arquitectura y coherencia ETL ↔ modelo dimensional (10) — origen, Stage, DW; considera correcciones por feedback del Avance 1.
2. Malla ETL relacional → **Stage** en SSIS, ejecución exitosa (15).
3. Transformaciones y calidad de datos en la carga a Stage (10) — sustentadas en problemas reales de los datos.
4. Malla ETL **Stage → DW**, ejecución exitosa (15).
5. Transformaciones, reglas de negocio y consistencia con el perfilamiento (15) — incluye correcciones del feedback del Avance 1.
6. Validación de ejecución, transferencia e integridad (15) — recuentos, consultas de validación, evidencias.
7. Presentación y demo en vivo (15) — 10 min, ejecutar la ETL en vivo, explicar transformaciones.
8. Calidad del informe, conclusiones y bibliografía (5) — usar la plantilla del Avance 2.

Plantilla del informe 2: Portada, Índice, 1 Introducción, 2 Objetivos, 3 Desarrollo (3.1 Malla ETL para poblar el área de Stage, 3.2 Malla ETL para poblar el Data Warehouse), 4 Conclusiones, 5 Bibliografía.

## Esquema fuente (`KentFoods`)
`Ordenes`, `DetalleOrden`, `Clientes`, `Empleados`, `Territorios`, `TerritoriosEmpleados`, `Regiones`, `Productos`, `Categorias`, `Proveedores`, `Transportistas`.
La región **no** cuelga de `Ordenes` ni de `Clientes`: se llega vía el empleado que tomó la orden (`Ordenes.EmpleadoID → TerritoriosEmpleados → Territorios → Regiones`).

## Modelo dimensional destino (`KentFoods_DW`, verificado el 31-08-2026)
6 dimensiones: `Dim_Tiempo` (FechaKey AAAAMMDD), `Dim_Producto`, `Dim_Cliente` (`ClienteID` sustituta IDENTITY + `ClienteCodigo` única, tras la corrección del Avance 2), `Dim_Transportista`, `Dim_Empleado` (EmpleadoID, NombreEmpleado, Territorio, Región), `Dim_Proveedor` (ProveedorID, Proveedor, Ciudad, País).
`Fact_Ventas`: grano = una línea de producto por orden; PK compuesta `id_orden`+`id_producto`; 7 FK. Medidas: `cantidad`, `precio_unitario`, `descuento`, `monto_neto` (= precio × cantidad × (1−descuento)), `dias_envio` (= DATEDIFF(día, FechaOrden, FechaEnvio), calculado en el ETL).
Nullables: `id_transportista`, `id_fecha_envio`, `dias_envio`; el resto NOT NULL.
`dias_envio` es semi-aditivo (dato de cabecera de orden repetido por línea): no sumar entre líneas; agrupar por `id_orden` y luego promediar por transportista.

## KPIs (validados contra la BD)
1. **KPI1 Tiempo promedio de envío** por transportista (promedio): Σ(FechaEnvio−FechaOrden) / nº órdenes.
2. **KPI2 Variación de ventas por región** (variación): (Ventas r,t − Ventas r,t−1) / Ventas r,t−1 × 100.
3. **KPI3 Ventas totales por proveedor**: Σ(PrecioUnitario × Cantidad × (1−Descuento)). Es ingreso, **no rentabilidad** (`Productos` no tiene costo).
4. **KPI4 Promedio de compras por pedido, por cliente** (promedio): Σ Cantidad / nº órdenes.
5. **KPI5 % de venta por categoría** (ratio): Venta categoría / Venta empresa × 100.

## Hallazgos de calidad de datos (insumo para el perfilamiento y las reglas de negocio de la ETL)
- **21 órdenes sin `FechaEnvio`** (pedidos no despachados): `id_fecha_envio` y `dias_envio` quedan NULL y se excluyen del promedio de KPI1.
- **Duplicación de ventas por región (Q2):** unir `Ordenes → Empleados → TerritoriosEmpleados → Territorios → Regiones` sin deduplicar multiplica las ventas (4,9x: $6.205.303 vs $1.265.793), porque cada empleado cubre de 2 a 10 territorios (los 9 cubren más de uno). Verificado con el perfilamiento: **cada territorio tiene un solo empleado** (49 de 49), o sea la relación es uno-a-muchos (empleado → territorios), no muchos-a-muchos. Con una fila por empleado, la suma de las 4 regiones cuadra con la venta total.
- **Jerarquía Territorio no confiable:** los territorios de un mismo empleado caen siempre en **una sola región**, por eso País > Región es confiable. Pero `Dim_Empleado.Territorio` es un único campo por empleado, y elegir 1 de sus 2–10 territorios es arbitrario; la venta no tiene territorio propio. Ninguno de los 5 KPIs necesita nivel Territorio.
  - **Decisión (06-10-2026, Avance 2):** se asigna el menor `TerritorioID` por empleado y se declara como limitación conocida en el informe. La bridge table Kimball con factor de ponderación **no se implementó**; queda como mejora futura.
- **Clave de cliente:** `Clientes.ClienteID` es `nchar` alfanumérico (`ALFKI`), pero el DW del Avance 1 la tenía como `int` → corregido con clave sustituta + `ClienteCodigo`.
- **`DetalleOrden.Descuento` es `real`** (0,15000001, etc.) → redondeo a `decimal(5,2)`. **`Regiones.Region` / `Territorios.Territorio` son `nchar(100)`** con relleno de espacios (en SQL Server `=` ignora los espacios finales: comparar con `DATALENGTH`). El precio en `DetalleOrden` difiere del de `Productos` en 658 de 2.155 líneas (se usa el de la línea).
- Totales de control del origen: 830 órdenes, 2.155 líneas, 51.317 unidades, venta neta $1.265.793,04 (el DW suma $1.265.793,29: redondeo por línea).
- No hay columna de costo en `Productos`: el modelo no puede medir margen/rentabilidad. Tampoco hay fecha de entrega al cliente: KPI 1 mide despacho.

## Lecciones del Avance 1
- El informe oficial subido tiene vacío 3.1 "Preguntas:" (faltan las 5 preguntas). Texto recuperado en `entrega_avance1_oficial/NOTA_seccion_faltante.md`. **Revisar el PDF final completo antes de subir cualquier entrega.**
- Redacción en tercera persona (regla del caso); evitar "nuestro/nos".
- El feedback del profesor sobre el Avance 1 no está en el repo; lo único que se conoce viene del borrador del Doc del Avance 2 (KPI 1 despacho vs entrega; preguntas omitidas). La rúbrica de Avance 2 lo menciona en los criterios 1 y 5. Pedir el texto original al equipo.
- **Revisar el PDF final completo antes de subir cualquier entrega** (en el Avance 1 se subió con una sección vacía).

## Convenciones de trabajo
- **Empezar a trabajar solo cuando el usuario lo dice de forma explícita** ("empieza", "dale, hazlo"); mientras no, solo lectura.
- Acciones que el clasificador de seguridad bloquea: borrar archivos sin trackear (`rm`) y comandos PowerShell largos que mezclan `DELETE`/borrados con otras cosas. Usar `git rm` para archivos versionados y poner los SQL de borrado en archivos `.sql`.
- Queries y análisis se hacen contra `KentFoods` (SQL Server) directamente.
- El usuario redacta el informe final en el doc del navegador; a Claude le toca ayudar con el análisis, queries, diseño de la ETL y mantener este tracker.
- **Sin comentarios meta en textos listos para pegar** (informe, Doc, código, comentarios de código, mensajes de commit): nada de aclaraciones como "(reemplaza la descripción anterior…)" ni notas sobre cómo o por qué se redactó. **Motivo:** delatan que se usó IA y el profesor podría tomarlo como evidencia de falta a la integridad académica; el usuario reaccionó con mucha firmeza cuando ocurrió. Las explicaciones van en el chat, alrededor del bloque, nunca dentro. El bloque pegable debe ser solo el contenido final, en tercera persona.
- **Google Doc del informe:** Claude no puede editarlo (no hay conector de escritura). Sí puede leerlo si el enlace es accesible: `WebFetch` a `https://docs.google.com/document/d/<ID>/export?format=txt`, que redirige a `googleusercontent.com`; hay que repetir `WebFetch` con la URL de redirección y pedir el texto completo sin resumir. El `<ID>` se lo pide a la persona usuaria (el enlace no se versiona). El texto para pegar se deja en `avance2/informe/` en Markdown y la persona lo pega con *Editar → Pegar desde Markdown*.
- La extensión oficial *Claude in Chrome* (Chrome Web Store) permitiría escribir en el Doc desde el navegador; no es necesaria para el flujo anterior. "Control Chrome" (lista de extensiones de la app) es solo para macOS y no sirve en Windows.
