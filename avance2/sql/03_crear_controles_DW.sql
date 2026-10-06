-- ============================================================
-- 03_crear_controles_DW.sql  |  Procedimiento de control del Data Warehouse
-- Compara Stage vs DW (conteos, venta total, integridad referencial, envíos pendientes),
-- registra el resultado en KentFoods_STAGE.dbo.LOG_CARGA y falla si hay diferencias.
-- Requiere que existan KentFoods_DW y KentFoods_STAGE. Idempotente.
-- ============================================================
SET NOCOUNT ON;
USE KentFoods_DW;
GO

CREATE OR ALTER PROCEDURE dbo.SP_CONTROL_DW
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @e int = 0;
    CREATE TABLE #ctl (control varchar(60), esperado decimal(18,2), obtenido decimal(18,2), tolerancia decimal(18,2));

    -- 1) Conteos Stage vs DW
    INSERT #ctl SELECT 'Dim_Cliente = ST_CLIENTE',             (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_CLIENTE),       (SELECT COUNT(*) FROM dbo.Dim_Cliente), 0;
    INSERT #ctl SELECT 'Dim_Proveedor = ST_PROVEEDOR',         (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_PROVEEDOR),     (SELECT COUNT(*) FROM dbo.Dim_Proveedor), 0;
    INSERT #ctl SELECT 'Dim_Transportista = ST_TRANSPORTISTA', (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_TRANSPORTISTA), (SELECT COUNT(*) FROM dbo.Dim_Transportista), 0;
    INSERT #ctl SELECT 'Dim_Producto = ST_PRODUCTO',           (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_PRODUCTO),      (SELECT COUNT(*) FROM dbo.Dim_Producto), 0;
    INSERT #ctl SELECT 'Dim_Empleado = ST_EMPLEADO',           (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_EMPLEADO),      (SELECT COUNT(*) FROM dbo.Dim_Empleado), 0;
    INSERT #ctl SELECT 'Fact_Ventas = ST_DETALLE (lineas)',    (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_DETALLE),       (SELECT COUNT(*) FROM dbo.Fact_Ventas), 0;

    -- 2) Medidas
    INSERT #ctl SELECT 'Fact_Ventas unidades = ST_DETALLE',
        (SELECT SUM(CAST(Cantidad AS bigint)) FROM KentFoods_STAGE.dbo.ST_DETALLE), (SELECT SUM(CAST(cantidad AS bigint)) FROM dbo.Fact_Ventas), 0;
    INSERT #ctl SELECT 'Fact_Ventas venta neta = ST_DETALLE (tol. $1 por redondeo)',
        (SELECT SUM(PrecioUnitario * Cantidad * (1 - Descuento)) FROM KentFoods_STAGE.dbo.ST_DETALLE), (SELECT SUM(monto_neto) FROM dbo.Fact_Ventas), 1.00;

    -- 3) Regla de envíos: lineas sin fecha de envío en el DW = lineas de ordenes sin FechaEnvio en Stage
    INSERT #ctl SELECT 'Lineas sin fecha de envio (pendientes)',
        (SELECT COUNT(*) FROM KentFoods_STAGE.dbo.ST_DETALLE d JOIN KentFoods_STAGE.dbo.ST_ORDEN o ON o.OrdenID = d.OrdenID WHERE o.FechaEnvio IS NULL),
        (SELECT COUNT(*) FROM dbo.Fact_Ventas WHERE id_fecha_envio IS NULL), 0;
    INSERT #ctl SELECT 'dias_envio nulo solo si no hay fecha de envio', 0,
        (SELECT COUNT(*) FROM dbo.Fact_Ventas WHERE (CASE WHEN dias_envio IS NULL THEN 1 ELSE 0 END) <> (CASE WHEN id_fecha_envio IS NULL THEN 1 ELSE 0 END)), 0;

    -- 4) Integridad referencial: hechos sin dimension (deben ser 0)
    INSERT #ctl SELECT 'Huerfanos id_fecha_orden', 0, (SELECT COUNT(*) FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Tiempo d WHERE d.FechaKey = f.id_fecha_orden)), 0;
    INSERT #ctl SELECT 'Huerfanos id_fecha_envio', 0, (SELECT COUNT(*) FROM dbo.Fact_Ventas f WHERE f.id_fecha_envio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Dim_Tiempo d WHERE d.FechaKey = f.id_fecha_envio)), 0;
    INSERT #ctl SELECT 'Huerfanos id_cliente', 0, (SELECT COUNT(*) FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Cliente d WHERE d.ClienteID = f.id_cliente)), 0;
    INSERT #ctl SELECT 'Huerfanos id_transportista', 0, (SELECT COUNT(*) FROM dbo.Fact_Ventas f WHERE f.id_transportista IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Dim_Transportista d WHERE d.TransportistaID = f.id_transportista)), 0;
    INSERT #ctl SELECT 'Huerfanos id_empleado', 0, (SELECT COUNT(*) FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Empleado d WHERE d.EmpleadoID = f.id_empleado)), 0;
    INSERT #ctl SELECT 'Huerfanos id_proveedor', 0, (SELECT COUNT(*) FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Proveedor d WHERE d.ProveedorID = f.id_proveedor)), 0;
    INSERT #ctl SELECT 'Huerfanos id_producto', 0, (SELECT COUNT(*) FROM dbo.Fact_Ventas f WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Producto d WHERE d.ProductoID = f.id_producto)), 0;

    SELECT control, esperado, obtenido, obtenido - esperado AS diferencia,
           CASE WHEN ABS(obtenido - esperado) <= tolerancia THEN 'OK' ELSE 'DIFERENCIA' END AS estado
    FROM #ctl;

    SELECT @e = COUNT(*) FROM #ctl WHERE ABS(obtenido - esperado) > tolerancia;

    INSERT INTO KentFoods_STAGE.dbo.LOG_CARGA (Paquete, Tabla, Filas)
    SELECT '02_ETL_KentFoods_Stage_DW', 'Dim_Tiempo',        COUNT(*) FROM dbo.Dim_Tiempo        UNION ALL
    SELECT '02_ETL_KentFoods_Stage_DW', 'Dim_Transportista', COUNT(*) FROM dbo.Dim_Transportista UNION ALL
    SELECT '02_ETL_KentFoods_Stage_DW', 'Dim_Proveedor',     COUNT(*) FROM dbo.Dim_Proveedor     UNION ALL
    SELECT '02_ETL_KentFoods_Stage_DW', 'Dim_Producto',      COUNT(*) FROM dbo.Dim_Producto      UNION ALL
    SELECT '02_ETL_KentFoods_Stage_DW', 'Dim_Cliente',       COUNT(*) FROM dbo.Dim_Cliente       UNION ALL
    SELECT '02_ETL_KentFoods_Stage_DW', 'Dim_Empleado',      COUNT(*) FROM dbo.Dim_Empleado      UNION ALL
    SELECT '02_ETL_KentFoods_Stage_DW', 'Fact_Ventas',       COUNT(*) FROM dbo.Fact_Ventas;

    IF @e > 0 RAISERROR('SP_CONTROL_DW: %d controles con diferencias entre Stage y DW.', 16, 1, @e);
END
GO
PRINT 'SP_CONTROL_DW creado en KentFoods_DW.';
