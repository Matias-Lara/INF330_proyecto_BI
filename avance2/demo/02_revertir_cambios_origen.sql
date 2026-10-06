-- ============================================================
-- DEMO · 02_revertir_cambios_origen.sql
-- Deja el origen KentFoods exactamente como estaba antes de 01_simular_cambios_en_origen.sql
-- (despues conviene reiniciar el DW con avance2\sql\04_reiniciar_DW.sql y volver a ejecutar la ETL).
-- ============================================================
SET NOCOUNT ON;
USE KentFoods;

DELETE FROM dbo.DetalleOrden WHERE OrdenID = 99999;
DELETE FROM dbo.Ordenes      WHERE OrdenID = 99999;
UPDATE dbo.Ordenes  SET FechaEnvio = NULL WHERE OrdenID = 11008;
UPDATE dbo.Clientes SET Ciudad = N'Berlin' WHERE ClienteID = N'ALFKI';

PRINT 'Origen revertido. Valores originales: 830 ordenes, 2155 lineas, venta 1265793,04, 21 ordenes sin envio.';
SELECT (SELECT COUNT(*) FROM dbo.Ordenes) AS ordenes,
       (SELECT COUNT(*) FROM dbo.DetalleOrden) AS lineas,
       (SELECT CAST(SUM(PrecioUnitario * Cantidad * (1 - Descuento)) AS decimal(18,2)) FROM dbo.DetalleOrden) AS venta,
       (SELECT COUNT(*) FROM dbo.Ordenes WHERE FechaEnvio IS NULL) AS ordenes_sin_envio,
       (SELECT Ciudad FROM dbo.Clientes WHERE ClienteID = N'ALFKI') AS ciudad_alfki;
