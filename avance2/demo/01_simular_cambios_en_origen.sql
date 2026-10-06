-- ============================================================
-- DEMO · 01_simular_cambios_en_origen.sql
-- Simula actividad del negocio en KentFoods (origen) para mostrar la carga INCREMENTAL:
--   1) se despacha una orden que estaba pendiente (11008)      -> debe completarse fecha de envio / dias_envio en el DW
--   2) llega una orden nueva (99999) con 2 lineas              -> debe cargarse como hechos nuevos
--   3) un cliente cambia de ciudad (ALFKI)                      -> debe actualizarse Dim_Cliente (sin duplicar)
-- Despues de ejecutar esto: correr el paquete 01 y el paquete 02, y revisar con SP_CONTROL_DW.
-- Para volver al estado original del origen: 02_revertir_cambios_origen.sql
-- ============================================================
SET NOCOUNT ON;
USE KentFoods;

UPDATE dbo.Ordenes SET FechaEnvio = '2018-04-13' WHERE OrdenID = 11008;

INSERT dbo.Ordenes (OrdenID, ClienteID, EmpleadoID, FechaOrden, FechaEnvio, EnviadoPor)
VALUES (99999, N'ALFKI', 1, '2018-05-07', NULL, 1);
INSERT dbo.DetalleOrden (OrdenID, ProductoID, PrecioUnitario, Cantidad, Descuento)
VALUES (99999, 1, 18.00, 10, 0.1), (99999, 2, 19.00, 5, 0);

UPDATE dbo.Clientes SET Ciudad = N'Berlin TEST' WHERE ClienteID = N'ALFKI';

PRINT 'Cambios aplicados al origen. Esperado en el DW tras la ETL: +1 orden, +2 lineas, venta +257,00, 11008 con envio, ALFKI en "Berlin TEST".';
