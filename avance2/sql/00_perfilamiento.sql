-- ============================================================
-- 00_perfilamiento.sql  |  Perfilamiento de datos del origen KentFoods
-- Solo lectura. Ejecutar contra la base KentFoods.
-- ============================================================
SET NOCOUNT ON;
USE KentFoods;

PRINT '=== P01. Filas por tabla ===';
SELECT 'Ordenes' AS tabla, COUNT(*) AS filas FROM dbo.Ordenes UNION ALL
SELECT 'DetalleOrden', COUNT(*) FROM dbo.DetalleOrden UNION ALL
SELECT 'Clientes', COUNT(*) FROM dbo.Clientes UNION ALL
SELECT 'Empleados', COUNT(*) FROM dbo.Empleados UNION ALL
SELECT 'Productos', COUNT(*) FROM dbo.Productos UNION ALL
SELECT 'Categorias', COUNT(*) FROM dbo.Categorias UNION ALL
SELECT 'Proveedores', COUNT(*) FROM dbo.Proveedores UNION ALL
SELECT 'Transportistas', COUNT(*) FROM dbo.Transportistas UNION ALL
SELECT 'Territorios', COUNT(*) FROM dbo.Territorios UNION ALL
SELECT 'TerritoriosEmpleados', COUNT(*) FROM dbo.TerritoriosEmpleados UNION ALL
SELECT 'Regiones', COUNT(*) FROM dbo.Regiones;

PRINT '=== P02. Nulos en columnas usadas por el modelo (Ordenes) ===';
SELECT COUNT(*) AS total,
       SUM(CASE WHEN ClienteID  IS NULL THEN 1 ELSE 0 END) AS sin_cliente,
       SUM(CASE WHEN EmpleadoID IS NULL THEN 1 ELSE 0 END) AS sin_empleado,
       SUM(CASE WHEN FechaOrden IS NULL THEN 1 ELSE 0 END) AS sin_fecha_orden,
       SUM(CASE WHEN FechaEnvio IS NULL THEN 1 ELSE 0 END) AS sin_fecha_envio,
       SUM(CASE WHEN EnviadoPor IS NULL THEN 1 ELSE 0 END) AS sin_transportista
FROM dbo.Ordenes;

PRINT '=== P03. Nulos en Productos / Clientes / Proveedores / Empleados ===';
SELECT 'Productos' AS tabla,
       SUM(CASE WHEN ProveedorID IS NULL THEN 1 ELSE 0 END) AS sin_proveedor,
       SUM(CASE WHEN CategoriaID IS NULL THEN 1 ELSE 0 END) AS sin_categoria,
       SUM(CASE WHEN PrecioUnitario IS NULL THEN 1 ELSE 0 END) AS sin_precio
FROM dbo.Productos;
SELECT 'Clientes' AS tabla,
       SUM(CASE WHEN Ciudad IS NULL THEN 1 ELSE 0 END) AS sin_ciudad,
       SUM(CASE WHEN CodigoPostal IS NULL THEN 1 ELSE 0 END) AS sin_cod_postal,
       SUM(CASE WHEN Pais IS NULL THEN 1 ELSE 0 END) AS sin_pais
FROM dbo.Clientes;
SELECT 'Proveedores' AS tabla,
       SUM(CASE WHEN Ciudad IS NULL THEN 1 ELSE 0 END) AS sin_ciudad,
       SUM(CASE WHEN Pais IS NULL THEN 1 ELSE 0 END) AS sin_pais
FROM dbo.Proveedores;

PRINT '=== P04. Unicidad de claves (duplicados) ===';
SELECT 'Ordenes.OrdenID' AS clave, COUNT(*) - COUNT(DISTINCT OrdenID) AS duplicados FROM dbo.Ordenes UNION ALL
SELECT 'Clientes.ClienteID', COUNT(*) - COUNT(DISTINCT ClienteID) FROM dbo.Clientes UNION ALL
SELECT 'Productos.ProductoID', COUNT(*) - COUNT(DISTINCT ProductoID) FROM dbo.Productos UNION ALL
SELECT 'Empleados.EmpleadoID', COUNT(*) - COUNT(DISTINCT EmpleadoID) FROM dbo.Empleados UNION ALL
SELECT 'Proveedores.ProveedorID', COUNT(*) - COUNT(DISTINCT ProveedorID) FROM dbo.Proveedores UNION ALL
SELECT 'Transportistas.TransportistaID', COUNT(*) - COUNT(DISTINCT TransportistaID) FROM dbo.Transportistas UNION ALL
SELECT 'DetalleOrden (OrdenID,ProductoID)', COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT OrdenID, ProductoID FROM dbo.DetalleOrden) d) FROM dbo.DetalleOrden;

PRINT '=== P05. Integridad referencial (huerfanos) ===';
SELECT 'Ordenes -> Clientes' AS relacion, COUNT(*) AS huerfanos FROM dbo.Ordenes o WHERE o.ClienteID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Clientes c WHERE c.ClienteID = o.ClienteID) UNION ALL
SELECT 'Ordenes -> Empleados', COUNT(*) FROM dbo.Ordenes o WHERE o.EmpleadoID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Empleados e WHERE e.EmpleadoID = o.EmpleadoID) UNION ALL
SELECT 'Ordenes -> Transportistas', COUNT(*) FROM dbo.Ordenes o WHERE o.EnviadoPor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Transportistas t WHERE t.TransportistaID = o.EnviadoPor) UNION ALL
SELECT 'DetalleOrden -> Ordenes', COUNT(*) FROM dbo.DetalleOrden d WHERE NOT EXISTS (SELECT 1 FROM dbo.Ordenes o WHERE o.OrdenID = d.OrdenID) UNION ALL
SELECT 'DetalleOrden -> Productos', COUNT(*) FROM dbo.DetalleOrden d WHERE NOT EXISTS (SELECT 1 FROM dbo.Productos p WHERE p.ProductoID = d.ProductoID) UNION ALL
SELECT 'Productos -> Proveedores', COUNT(*) FROM dbo.Productos p WHERE p.ProveedorID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedores v WHERE v.ProveedorID = p.ProveedorID) UNION ALL
SELECT 'Productos -> Categorias', COUNT(*) FROM dbo.Productos p WHERE p.CategoriaID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Categorias c WHERE c.CategoriaID = p.CategoriaID) UNION ALL
SELECT 'Ordenes sin ninguna linea de detalle', COUNT(*) FROM dbo.Ordenes o WHERE NOT EXISTS (SELECT 1 FROM dbo.DetalleOrden d WHERE d.OrdenID = o.OrdenID);

PRINT '=== P06. Fechas: rangos, hora, coherencia ===';
SELECT MIN(FechaOrden) AS min_orden, MAX(FechaOrden) AS max_orden,
       MIN(FechaEnvio) AS min_envio, MAX(FechaEnvio) AS max_envio,
       SUM(CASE WHEN FechaOrden <> CAST(FechaOrden AS date) THEN 1 ELSE 0 END) AS orden_con_hora,
       SUM(CASE WHEN FechaEnvio <> CAST(FechaEnvio AS date) THEN 1 ELSE 0 END) AS envio_con_hora,
       SUM(CASE WHEN FechaEnvio < FechaOrden THEN 1 ELSE 0 END) AS envio_antes_de_orden
FROM dbo.Ordenes;
SELECT MIN(DATEDIFF(DAY, FechaOrden, FechaEnvio)) AS min_dias_envio,
       MAX(DATEDIFF(DAY, FechaOrden, FechaEnvio)) AS max_dias_envio,
       AVG(CAST(DATEDIFF(DAY, FechaOrden, FechaEnvio) AS decimal(10,2))) AS prom_dias_envio
FROM dbo.Ordenes WHERE FechaEnvio IS NOT NULL;
SELECT YEAR(FechaOrden) AS anio, COUNT(*) AS ordenes FROM dbo.Ordenes GROUP BY YEAR(FechaOrden) ORDER BY 1;

PRINT '=== P07. DetalleOrden: rangos de medidas ===';
SELECT MIN(Cantidad) AS min_cant, MAX(Cantidad) AS max_cant,
       MIN(Descuento) AS min_desc, MAX(Descuento) AS max_desc,
       MIN(PrecioUnitario) AS min_precio, MAX(PrecioUnitario) AS max_precio,
       SUM(CASE WHEN Cantidad <= 0 THEN 1 ELSE 0 END) AS cant_no_positiva,
       SUM(CASE WHEN Descuento < 0 OR Descuento > 1 THEN 1 ELSE 0 END) AS desc_fuera_rango,
       SUM(CASE WHEN Descuento <> ROUND(Descuento,2) THEN 1 ELSE 0 END) AS desc_con_mas_de_2_decimales
FROM dbo.DetalleOrden;
SELECT DISTINCT Descuento FROM dbo.DetalleOrden ORDER BY 1;

PRINT '=== P08. Precio en DetalleOrden distinto del precio vigente en Productos ===';
SELECT SUM(CASE WHEN d.PrecioUnitario <> p.PrecioUnitario THEN 1 ELSE 0 END) AS lineas_precio_distinto, COUNT(*) AS lineas
FROM dbo.DetalleOrden d JOIN dbo.Productos p ON p.ProductoID = d.ProductoID;

PRINT '=== P09. Claves de cliente: formato (nchar(10) con relleno) ===';
SELECT MIN(LEN(ClienteID)) AS len_min, MAX(LEN(ClienteID)) AS len_max, MAX(DATALENGTH(ClienteID)/2) AS nchar_def,
       SUM(CASE WHEN ClienteID <> LTRIM(RTRIM(ClienteID)) THEN 1 ELSE 0 END) AS con_espacios_borde,
       SUM(CASE WHEN ISNUMERIC(ClienteID) = 1 THEN 1 ELSE 0 END) AS claves_numericas
FROM dbo.Clientes;
SELECT TOP 5 ClienteID, Empresa FROM dbo.Clientes ORDER BY ClienteID;

PRINT '=== P10. Texto: espacios sobrantes (comparando bytes, porque = ignora los espacios finales) y caracteres no convertibles a varchar ===';
SELECT 'Clientes.Empresa' AS campo, SUM(CASE WHEN DATALENGTH(Empresa) <> DATALENGTH(LTRIM(RTRIM(Empresa))) THEN 1 ELSE 0 END) AS con_espacios,
       SUM(CASE WHEN CAST(CAST(Empresa AS varchar(100)) AS nvarchar(100)) <> Empresa THEN 1 ELSE 0 END) AS no_convertibles FROM dbo.Clientes UNION ALL
SELECT 'Proveedores.Proveedor', SUM(CASE WHEN DATALENGTH(Proveedor) <> DATALENGTH(LTRIM(RTRIM(Proveedor))) THEN 1 ELSE 0 END),
       SUM(CASE WHEN CAST(CAST(Proveedor AS varchar(100)) AS nvarchar(100)) <> Proveedor THEN 1 ELSE 0 END) FROM dbo.Proveedores UNION ALL
SELECT 'Productos.Producto', SUM(CASE WHEN DATALENGTH(Producto) <> DATALENGTH(LTRIM(RTRIM(Producto))) THEN 1 ELSE 0 END),
       SUM(CASE WHEN CAST(CAST(Producto AS varchar(100)) AS nvarchar(100)) <> Producto THEN 1 ELSE 0 END) FROM dbo.Productos UNION ALL
SELECT 'Regiones.Region (nchar 100)', SUM(CASE WHEN DATALENGTH(Region) <> DATALENGTH(RTRIM(Region)) THEN 1 ELSE 0 END), 0 FROM dbo.Regiones UNION ALL
SELECT 'Territorios.Territorio (nchar 100)', SUM(CASE WHEN DATALENGTH(Territorio) <> DATALENGTH(RTRIM(Territorio)) THEN 1 ELSE 0 END), 0 FROM dbo.Territorios;
SELECT TOP 3 '[' + Region + ']' AS region_con_relleno, LEN(Region) AS len, DATALENGTH(Region)/2 AS ancho_nchar FROM dbo.Regiones;

PRINT '=== P11. Empleados: territorios y regiones cubiertos (muchos a muchos) ===';
SELECT e.EmpleadoID, e.Nombre + ' ' + e.Apellido AS empleado,
       COUNT(DISTINCT te.TerritorioID) AS territorios,
       COUNT(DISTINCT t.RegionID) AS regiones,
       MIN(t.RegionID) AS region_id
FROM dbo.Empleados e
LEFT JOIN dbo.TerritoriosEmpleados te ON te.EmpleadoID = e.EmpleadoID
LEFT JOIN dbo.Territorios t ON t.TerritorioID = te.TerritorioID
GROUP BY e.EmpleadoID, e.Nombre, e.Apellido ORDER BY e.EmpleadoID;

PRINT '=== P11b. Cardinalidad empleado-territorio (cada territorio ¿tiene un solo empleado?) ===';
SELECT (SELECT COUNT(*) FROM dbo.TerritoriosEmpleados) AS filas_puente,
       (SELECT COUNT(DISTINCT TerritorioID) FROM dbo.TerritoriosEmpleados) AS territorios_distintos,
       (SELECT COUNT(*) FROM (SELECT TerritorioID FROM dbo.TerritoriosEmpleados GROUP BY TerritorioID HAVING COUNT(*) > 1) x) AS territorios_con_mas_de_un_empleado,
       (SELECT COUNT(*) FROM (SELECT EmpleadoID FROM dbo.TerritoriosEmpleados GROUP BY EmpleadoID HAVING COUNT(*) > 1) x) AS empleados_con_mas_de_un_territorio;

PRINT '=== P12. Ordenes cuyo empleado no tiene territorio asignado ===';
SELECT COUNT(*) AS ordenes_sin_region
FROM dbo.Ordenes o
WHERE o.EmpleadoID IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.TerritoriosEmpleados te WHERE te.EmpleadoID = o.EmpleadoID);

PRINT '=== P13. Efecto de unir por TerritoriosEmpleados sin deduplicar (Q2) ===';
SELECT (SELECT CAST(SUM(d.PrecioUnitario*d.Cantidad*(1-d.Descuento)) AS decimal(18,2)) FROM dbo.DetalleOrden d) AS venta_total_real,
       (SELECT CAST(SUM(d.PrecioUnitario*d.Cantidad*(1-d.Descuento)) AS decimal(18,2))
        FROM dbo.Ordenes o JOIN dbo.DetalleOrden d ON d.OrdenID = o.OrdenID
        JOIN dbo.TerritoriosEmpleados te ON te.EmpleadoID = o.EmpleadoID) AS venta_con_join_sin_dedup,
       (SELECT CAST(SUM(d.PrecioUnitario*d.Cantidad*(1-d.Descuento)) AS decimal(18,2))
        FROM dbo.Ordenes o JOIN dbo.DetalleOrden d ON d.OrdenID = o.OrdenID
        JOIN (SELECT DISTINCT te.EmpleadoID, t.RegionID FROM dbo.TerritoriosEmpleados te JOIN dbo.Territorios t ON t.TerritorioID = te.TerritorioID) er ON er.EmpleadoID = o.EmpleadoID) AS venta_con_dedup;

PRINT '=== P14. Totales de control del origen (para validar el DW) ===';
SELECT COUNT(*) AS lineas_detalle,
       COUNT(DISTINCT OrdenID) AS ordenes_con_detalle,
       SUM(Cantidad) AS unidades,
       CAST(SUM(PrecioUnitario*Cantidad*(1-Descuento)) AS decimal(18,2)) AS venta_neta_total
FROM dbo.DetalleOrden;

PRINT '=== P15. Cobertura de los atributos de dimension sobre las ordenes ===';
SELECT SUM(CASE WHEN o.FechaEnvio IS NULL THEN 1 ELSE 0 END) AS lineas_sin_fecha_envio,
       SUM(CASE WHEN o.EnviadoPor IS NULL THEN 1 ELSE 0 END) AS lineas_sin_transportista,
       SUM(CASE WHEN p.ProveedorID IS NULL THEN 1 ELSE 0 END) AS lineas_sin_proveedor,
       SUM(CASE WHEN p.CategoriaID IS NULL THEN 1 ELSE 0 END) AS lineas_sin_categoria
FROM dbo.DetalleOrden d
JOIN dbo.Ordenes o ON o.OrdenID = d.OrdenID
JOIN dbo.Productos p ON p.ProductoID = d.ProductoID;
