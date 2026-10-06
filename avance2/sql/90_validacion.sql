-- ============================================================
-- 90_validacion.sql  |  Validación de las cargas Origen -> Stage -> DW y prueba de los 5 KPI
-- Solo lectura. Ejecutar después de los paquetes 01 y 02.
-- ============================================================
SET NOCOUNT ON;

PRINT '=== V1. Conteo de filas: Origen vs Stage vs DW ===';
SELECT 'Clientes / ST_CLIENTE / Dim_Cliente' AS entidad,
       (SELECT COUNT(*) FROM KentFoods.dbo.Clientes)        AS origen,
       (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_CLIENTE) AS stage,
       (SELECT COUNT(*) FROM KentFoods_DW.dbo.Dim_Cliente)   AS dw
UNION ALL SELECT 'Proveedores / ST_PROVEEDOR / Dim_Proveedor',
       (SELECT COUNT(*) FROM KentFoods.dbo.Proveedores), (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_PROVEEDOR), (SELECT COUNT(*) FROM KentFoods_DW.dbo.Dim_Proveedor)
UNION ALL SELECT 'Transportistas / ST_TRANSPORTISTA / Dim_Transportista',
       (SELECT COUNT(*) FROM KentFoods.dbo.Transportistas), (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_TRANSPORTISTA), (SELECT COUNT(*) FROM KentFoods_DW.dbo.Dim_Transportista)
UNION ALL SELECT 'Productos / ST_PRODUCTO / Dim_Producto',
       (SELECT COUNT(*) FROM KentFoods.dbo.Productos), (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_PRODUCTO), (SELECT COUNT(*) FROM KentFoods_DW.dbo.Dim_Producto)
UNION ALL SELECT 'Empleados / ST_EMPLEADO / Dim_Empleado',
       (SELECT COUNT(*) FROM KentFoods.dbo.Empleados), (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_EMPLEADO), (SELECT COUNT(*) FROM KentFoods_DW.dbo.Dim_Empleado)
UNION ALL SELECT 'Ordenes / ST_ORDEN / (fechas en Dim_Tiempo)',
       (SELECT COUNT(*) FROM KentFoods.dbo.Ordenes), (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_ORDEN), NULL
UNION ALL SELECT 'DetalleOrden / ST_DETALLE / Fact_Ventas',
       (SELECT COUNT(*) FROM KentFoods.dbo.DetalleOrden), (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_DETALLE), (SELECT COUNT(*) FROM KentFoods_DW.dbo.Fact_Ventas)
UNION ALL SELECT 'Dim_Tiempo (calendario 2016-2018)', NULL, NULL, (SELECT COUNT(*) FROM KentFoods_DW.dbo.Dim_Tiempo);

PRINT '=== V2. Venta neta total: Origen vs Stage vs DW (debe cuadrar con $1.265.793) ===';
SELECT CAST((SELECT SUM(PrecioUnitario * Cantidad * (1 - Descuento)) FROM KentFoods.dbo.DetalleOrden) AS decimal(18,2))       AS venta_origen,
       CAST((SELECT SUM(PrecioUnitario * Cantidad * (1 - Descuento)) FROM KentFoods_STAGE.dbo.ST_DETALLE) AS decimal(18,2))   AS venta_stage,
       CAST((SELECT SUM(monto_neto) FROM KentFoods_DW.dbo.Fact_Ventas) AS decimal(18,2))                                      AS venta_dw,
       CAST((SELECT SUM(monto_neto) FROM KentFoods_DW.dbo.Fact_Ventas)
          - (SELECT SUM(PrecioUnitario * Cantidad * (1 - Descuento)) FROM KentFoods.dbo.DetalleOrden) AS decimal(18,2))       AS diferencia_dw_vs_origen;

PRINT '=== V3. Unidades vendidas: Origen vs DW ===';
SELECT (SELECT SUM(CAST(Cantidad AS bigint)) FROM KentFoods.dbo.DetalleOrden) AS unidades_origen,
       (SELECT SUM(CAST(cantidad AS bigint)) FROM KentFoods_DW.dbo.Fact_Ventas) AS unidades_dw;

USE KentFoods_DW;

PRINT '=== V4. Integridad referencial del DW: hechos sin dimension (debe ser 0 en todas) ===';
SELECT 'id_fecha_orden'   AS fk, COUNT(*) AS huerfanos FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Tiempo d WHERE d.FechaKey = f.id_fecha_orden)
UNION ALL SELECT 'id_fecha_envio (no nulos)', COUNT(*) FROM dbo.Fact_Ventas f WHERE f.id_fecha_envio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Dim_Tiempo d WHERE d.FechaKey = f.id_fecha_envio)
UNION ALL SELECT 'id_cliente',       COUNT(*) FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Cliente d WHERE d.ClienteID = f.id_cliente)
UNION ALL SELECT 'id_transportista', COUNT(*) FROM dbo.Fact_Ventas f WHERE f.id_transportista IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Dim_Transportista d WHERE d.TransportistaID = f.id_transportista)
UNION ALL SELECT 'id_empleado',      COUNT(*) FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Empleado d WHERE d.EmpleadoID = f.id_empleado)
UNION ALL SELECT 'id_proveedor',     COUNT(*) FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Proveedor d WHERE d.ProveedorID = f.id_proveedor)
UNION ALL SELECT 'id_producto',      COUNT(*) FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Producto d WHERE d.ProductoID = f.id_producto);

PRINT '=== V5. Regla de los envios sin fecha (21 ordenes / 73 lineas en el origen) ===';
SELECT COUNT(*) AS lineas_sin_fecha_envio,
       COUNT(DISTINCT id_orden) AS ordenes_sin_fecha_envio,
       SUM(CASE WHEN dias_envio IS NULL THEN 1 ELSE 0 END) AS lineas_con_dias_envio_nulo
FROM dbo.Fact_Ventas WHERE id_fecha_envio IS NULL;

PRINT '=== V6. Dim_Tiempo ===';
SELECT COUNT(*) AS dias, MIN(Fecha) AS desde, MAX(Fecha) AS hasta,
       COUNT(DISTINCT Anio) AS anios, SUM(CASE WHEN FechaKey <> Anio*10000 + Mes*100 + Dia THEN 1 ELSE 0 END) AS claves_inconsistentes
FROM dbo.Dim_Tiempo;

PRINT '=== V7. Dim_Cliente: clave sustituta vs clave de negocio ===';
SELECT TOP 5 ClienteID, ClienteCodigo, NombreEmpresa, Ciudad, Pais FROM dbo.Dim_Cliente ORDER BY ClienteID;
SELECT COUNT(*) AS filas, COUNT(DISTINCT ClienteCodigo) AS codigos_unicos, MIN(ClienteID) AS id_min, MAX(ClienteID) AS id_max FROM dbo.Dim_Cliente;

PRINT '=== V8. Dim_Empleado (un territorio por empleado: menor TerritorioID; la region es confiable) ===';
SELECT EmpleadoID, NombreEmpleado, Territorio, Region FROM dbo.Dim_Empleado ORDER BY EmpleadoID;

PRINT '=== V9. Medidas: descuento redondeado y monto_neto ===';
SELECT MIN(descuento) AS desc_min, MAX(descuento) AS desc_max,
       SUM(CASE WHEN monto_neto <> ROUND(precio_unitario * cantidad * (1 - descuento), 2) THEN 1 ELSE 0 END) AS monto_mal_calculado,
       SUM(CASE WHEN monto_neto < 0 THEN 1 ELSE 0 END) AS montos_negativos
FROM dbo.Fact_Ventas;

PRINT '=== V10. Textos del DW sin relleno de espacios (debe ser 0) ===';
SELECT 'Dim_Empleado.Region' AS campo, SUM(CASE WHEN DATALENGTH(Region) <> DATALENGTH(RTRIM(Region)) THEN 1 ELSE 0 END) AS con_espacios FROM dbo.Dim_Empleado
UNION ALL SELECT 'Dim_Empleado.Territorio', SUM(CASE WHEN DATALENGTH(Territorio) <> DATALENGTH(RTRIM(Territorio)) THEN 1 ELSE 0 END) FROM dbo.Dim_Empleado
UNION ALL SELECT 'Dim_Cliente.ClienteCodigo', SUM(CASE WHEN DATALENGTH(ClienteCodigo) <> DATALENGTH(RTRIM(ClienteCodigo)) THEN 1 ELSE 0 END) FROM dbo.Dim_Cliente;

PRINT '=== K1. KPI 1 - Tiempo promedio de envio por transportista (dias); DW vs Origen ===';
SELECT t.Transportista,
       COUNT(*) AS ordenes_enviadas,
       CAST(AVG(CAST(o.dias_envio AS decimal(10,4))) AS decimal(10,2)) AS prom_dias_dw,
       (SELECT CAST(AVG(CAST(DATEDIFF(DAY, x.FechaOrden, x.FechaEnvio) AS decimal(10,4))) AS decimal(10,2))
        FROM KentFoods.dbo.Ordenes x WHERE x.EnviadoPor = t.TransportistaID AND x.FechaEnvio IS NOT NULL) AS prom_dias_origen
FROM (SELECT id_orden, id_transportista, MAX(dias_envio) AS dias_envio
      FROM dbo.Fact_Ventas WHERE dias_envio IS NOT NULL GROUP BY id_orden, id_transportista) AS o
JOIN dbo.Dim_Transportista t ON t.TransportistaID = o.id_transportista
GROUP BY t.TransportistaID, t.Transportista ORDER BY t.Transportista;

PRINT '=== K2. KPI 2 - Ventas y variacion % por region y anio (sin duplicacion: Region viene de Dim_Empleado) ===';
WITH V AS (
    SELECT e.Region, tm.Anio, SUM(f.monto_neto) AS ventas
    FROM dbo.Fact_Ventas f
    JOIN dbo.Dim_Empleado e ON e.EmpleadoID = f.id_empleado
    JOIN dbo.Dim_Tiempo  tm ON tm.FechaKey = f.id_fecha_orden
    GROUP BY e.Region, tm.Anio
)
SELECT Region, Anio, CAST(ventas AS decimal(18,2)) AS ventas,
       CAST((ventas - LAG(ventas) OVER (PARTITION BY Region ORDER BY Anio)) * 100.0
            / NULLIF(LAG(ventas) OVER (PARTITION BY Region ORDER BY Anio), 0) AS decimal(10,2)) AS variacion_pct
FROM V ORDER BY Region, Anio;
SELECT CAST(SUM(f.monto_neto) AS decimal(18,2)) AS suma_de_las_regiones
FROM dbo.Fact_Ventas f JOIN dbo.Dim_Empleado e ON e.EmpleadoID = f.id_empleado;

PRINT '=== K3. KPI 3 - Ventas totales por proveedor (top 5) y control ===';
SELECT TOP 5 p.Proveedor, CAST(SUM(f.monto_neto) AS decimal(18,2)) AS ventas
FROM dbo.Fact_Ventas f JOIN dbo.Dim_Proveedor p ON p.ProveedorID = f.id_proveedor
GROUP BY p.ProveedorID, p.Proveedor ORDER BY SUM(f.monto_neto) DESC;
SELECT COUNT(DISTINCT id_proveedor) AS proveedores_con_ventas, CAST(SUM(monto_neto) AS decimal(18,2)) AS suma_proveedores FROM dbo.Fact_Ventas;

PRINT '=== K4. KPI 4 - Promedio de unidades por pedido, por cliente (top 5) ===';
SELECT TOP 5 c.ClienteCodigo, c.NombreEmpresa,
       COUNT(DISTINCT f.id_orden) AS pedidos, SUM(f.cantidad) AS unidades,
       CAST(SUM(f.cantidad) * 1.0 / COUNT(DISTINCT f.id_orden) AS decimal(10,2)) AS unidades_por_pedido
FROM dbo.Fact_Ventas f JOIN dbo.Dim_Cliente c ON c.ClienteID = f.id_cliente
GROUP BY c.ClienteID, c.ClienteCodigo, c.NombreEmpresa ORDER BY unidades_por_pedido DESC;

PRINT '=== K5. KPI 5 - % de la venta total por categoria ===';
SELECT p.NombreCategoria,
       CAST(SUM(f.monto_neto) AS decimal(18,2)) AS ventas,
       CAST(SUM(f.monto_neto) * 100.0 / (SELECT SUM(monto_neto) FROM dbo.Fact_Ventas) AS decimal(10,2)) AS pct_venta
FROM dbo.Fact_Ventas f JOIN dbo.Dim_Producto p ON p.ProductoID = f.id_producto
GROUP BY p.CategoriaID, p.NombreCategoria ORDER BY SUM(f.monto_neto) DESC;

PRINT '=== K6. Control cruzado KPI 5: ventas por categoria DW vs Origen (diferencia maxima en $) ===';
SELECT MAX(ABS(dw.ventas - og.ventas)) AS diferencia_maxima_por_categoria
FROM (SELECT p.CategoriaID, SUM(f.monto_neto) AS ventas FROM dbo.Fact_Ventas f JOIN dbo.Dim_Producto p ON p.ProductoID = f.id_producto GROUP BY p.CategoriaID) dw
JOIN (SELECT pr.CategoriaID, SUM(d.PrecioUnitario * d.Cantidad * (1 - d.Descuento)) AS ventas
      FROM KentFoods.dbo.DetalleOrden d JOIN KentFoods.dbo.Productos pr ON pr.ProductoID = d.ProductoID GROUP BY pr.CategoriaID) og
  ON og.CategoriaID = dw.CategoriaID;

PRINT '=== L1. Bitacora de cargas (LOG_CARGA, ultima ejecucion de cada paquete) ===';
SELECT Paquete, Tabla, Filas, Fecha FROM KentFoods_STAGE.dbo.LOG_CARGA ORDER BY LogID;
