-- ============================================================
-- 04_reiniciar_DW.sql  |  Deja el Data Warehouse vacío (para repetir la "prueba limpia" de la demo)
-- Borra hechos y dimensiones respetando las claves foráneas y reinicia la clave sustituta de Dim_Cliente.
-- No toca el origen (KentFoods) ni el Stage.
-- ============================================================
SET NOCOUNT ON;
USE KentFoods_DW;

DELETE FROM dbo.Fact_Ventas;
DELETE FROM dbo.Dim_Empleado;
DELETE FROM dbo.Dim_Producto;
DELETE FROM dbo.Dim_Proveedor;
DELETE FROM dbo.Dim_Transportista;
DELETE FROM dbo.Dim_Cliente;
DELETE FROM dbo.Dim_Tiempo;

-- Si la identidad ya se usó, la siguiente clave sustituta vuelve a ser 1
IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Dim_Cliente') AND last_value IS NOT NULL)
    DBCC CHECKIDENT ('dbo.Dim_Cliente', RESEED, 0) WITH NO_INFOMSGS;

SELECT 'Fact_Ventas' AS tabla, COUNT(*) AS filas FROM dbo.Fact_Ventas UNION ALL
SELECT 'Dim_Cliente', COUNT(*) FROM dbo.Dim_Cliente UNION ALL
SELECT 'Dim_Empleado', COUNT(*) FROM dbo.Dim_Empleado UNION ALL
SELECT 'Dim_Producto', COUNT(*) FROM dbo.Dim_Producto UNION ALL
SELECT 'Dim_Proveedor', COUNT(*) FROM dbo.Dim_Proveedor UNION ALL
SELECT 'Dim_Transportista', COUNT(*) FROM dbo.Dim_Transportista UNION ALL
SELECT 'Dim_Tiempo', COUNT(*) FROM dbo.Dim_Tiempo;
PRINT 'DW reiniciado: todas las tablas en 0 filas.';
