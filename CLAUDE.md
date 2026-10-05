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
- `bd/` — `KentFoods.bak` (BD relacional fuente, esquema Northwind) y `KentFoods_DW.bak` (DW dimensional físico; solo esquema, **0 filas**, es el destino de la ETL).
- `material_curso/` — `Caso_Semestral_FormaC.pdf` (caso + reglas de formato del informe: tercera persona, Calibri 11, máx. 50 págs., 6 secciones) y el manual de instalación del entorno (Visual Studio/SSIS/SQL Server).
- `instrucciones_avance1/` — plantilla, rúbrica e instrucciones del Avance 1 (ya entregado).
- `entrega_avance1_oficial/` — informe y PPT **tal como se subieron al aula virtual**. Ver `NOTA_seccion_faltante.md`.
- `instrucciones_avance2/` — plantilla del informe 2 (`.docx`), rúbrica (`.xlsx`) e instrucciones del buzón.
- El historial de git conserva el borrador del informe 1, la PPT anterior y el brief de la PPT (commit `cb322fd`).

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
6 dimensiones: `Dim_Tiempo`, `Dim_Producto`, `Dim_Cliente`, `Dim_Transportista`, `Dim_Empleado` (EmpleadoID, NombreEmpleado, Territorio, Región), `Dim_Proveedor` (ProveedorID, Proveedor, Ciudad, País).
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
- **Duplicación de ventas por región (Q2):** unir `Ordenes → Empleados → TerritoriosEmpleados → Territorios → Regiones` sin deduplicar multiplica las ventas (~5x), porque `TerritoriosEmpleados` es muchos-a-muchos real (7 de 9 empleados cubren ≥3 territorios; rango 2–10; ninguno cubre solo 1). Fix: `SELECT DISTINCT EmpleadoID, RegionID` antes de unir. Con el fix, la suma de las 4 regiones cuadra con la venta total ($1.265.793).
- **Jerarquía Territorio no confiable:** los territorios de un mismo empleado caen siempre en **una sola región**, por eso País > Región es confiable. Pero `Dim_Empleado.Territorio` es un único campo por empleado, y elegir 1 de sus 2–10 territorios es arbitrario; la venta no tiene territorio propio. Ninguno de los 5 KPIs necesita nivel Territorio.
  - **Decisión del equipo (01-09-2026):** declararlo como limitación conocida y resolverlo en Avance 2 con una bridge table Kimball (factor de ponderación), o en su defecto documentar el criterio de selección y la limitación. **Decidir esto antes de construir la carga de `Dim_Empleado`.**
- No hay columna de costo en `Productos`: el modelo no puede medir margen/rentabilidad.

## Lecciones del Avance 1
- El informe oficial subido tiene vacío 3.1 "Preguntas:" (faltan las 5 preguntas). Texto recuperado en `entrega_avance1_oficial/NOTA_seccion_faltante.md`. **Revisar el PDF final completo antes de subir cualquier entrega.**
- Redacción en tercera persona (regla del caso); evitar "nuestro/nos".
- No tenemos aún feedback del profesor sobre el Avance 1; la rúbrica de Avance 2 lo menciona en los criterios 1 y 5. Pedirlo o inferirlo.

## Convenciones de trabajo
- Queries y análisis se hacen contra `KentFoods` (SQL Server) directamente.
- El usuario redacta el informe final en el doc del navegador; a Claude le toca ayudar con el análisis, queries, diseño de la ETL y mantener este tracker.
- Tipo de contenido en entregables: sin comentarios meta sobre edición ni sobre IA dentro de textos listos para pegar.
