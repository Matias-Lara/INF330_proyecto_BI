-- ============================================================
-- DEMO · 03_consultas_demo.sql
-- ============================================================

-- A) Estado de las tres bases (antes de ejecutar la ETL: Stage y DW vacíos)
SELECT 'ORIGEN  Ordenes'        AS tabla, COUNT(*) AS filas FROM KentFoods.dbo.Ordenes UNION ALL
SELECT 'ORIGEN  DetalleOrden',  COUNT(*) FROM KentFoods.dbo.DetalleOrden UNION ALL
SELECT 'STAGE   ST_DETALLE',    COUNT(*) FROM KentFoods_STAGE.dbo.ST_DETALLE UNION ALL
SELECT 'DW      Fact_Ventas',   COUNT(*) FROM KentFoods_DW.dbo.Fact_Ventas UNION ALL
SELECT 'DW      Dim_Cliente',   COUNT(*) FROM KentFoods_DW.dbo.Dim_Cliente;

-- B) Control del Stage (después del paquete 01)
EXEC KentFoods_STAGE.dbo.SP_CONTROL_STAGE;

-- C) Control del DW (después del paquete 02)
EXEC KentFoods_DW.dbo.SP_CONTROL_DW;

-- D) Una transformación: Dim_Cliente (clave de negocio ClienteCodigo -> clave sustituta ClienteID)
SELECT TOP 5 ClienteID, ClienteCodigo, NombreEmpresa, Ciudad, Pais FROM KentFoods_DW.dbo.Dim_Cliente ORDER BY ClienteID;

-- E) Otra transformación: de DetalleOrden (origen) a Fact_Ventas (DW) para una misma línea
SELECT 'ORIGEN' AS capa, d.OrdenID, d.ProductoID, d.PrecioUnitario, d.Cantidad, d.Descuento, NULL AS monto_neto, NULL AS dias_envio
FROM KentFoods.dbo.DetalleOrden d WHERE d.OrdenID = 10248
UNION ALL
SELECT 'DW', f.id_orden, f.id_producto, f.precio_unitario, f.cantidad, f.descuento, f.monto_neto, f.dias_envio
FROM KentFoods_DW.dbo.Fact_Ventas f WHERE f.id_orden = 10248;

-- F) Órdenes pendientes de despacho (dias_envio queda NULL por regla de negocio)
SELECT COUNT(*) AS lineas_pendientes, COUNT(DISTINCT id_orden) AS ordenes_pendientes
FROM KentFoods_DW.dbo.Fact_Ventas WHERE id_fecha_envio IS NULL;

-- G) KPI 1: tiempo promedio de envío por transportista (promedia por orden, no por línea)
SELECT t.Transportista, COUNT(*) AS ordenes_enviadas,
       CAST(AVG(CAST(o.dias_envio AS decimal(10,4))) AS decimal(10,2)) AS prom_dias_envio
FROM (SELECT id_orden, id_transportista, MAX(dias_envio) AS dias_envio
      FROM KentFoods_DW.dbo.Fact_Ventas WHERE dias_envio IS NOT NULL GROUP BY id_orden, id_transportista) o
JOIN KentFoods_DW.dbo.Dim_Transportista t ON t.TransportistaID = o.id_transportista
GROUP BY t.Transportista ORDER BY prom_dias_envio;

-- H) KPI 5: % de la venta total por categoría
SELECT p.NombreCategoria, CAST(SUM(f.monto_neto) AS decimal(18,2)) AS ventas,
       CAST(SUM(f.monto_neto) * 100.0 / (SELECT SUM(monto_neto) FROM KentFoods_DW.dbo.Fact_Ventas) AS decimal(10,2)) AS pct_venta
FROM KentFoods_DW.dbo.Fact_Ventas f JOIN KentFoods_DW.dbo.Dim_Producto p ON p.ProductoID = f.id_producto
GROUP BY p.CategoriaID, p.NombreCategoria ORDER BY SUM(f.monto_neto) DESC;

-- I) Bitácora de cargas
SELECT * FROM KentFoods_STAGE.dbo.LOG_CARGA ORDER BY LogID;
