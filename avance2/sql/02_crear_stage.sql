-- ============================================================
-- 02_crear_stage.sql  |  Crea la base del área de Stage (KentFoods_STAGE)
-- Las tablas ST_* son copias depuradas del origen (sin claves foráneas), pensadas
-- para vaciarse y recargarse completas en cada ejecución del paquete 01.
-- Idempotente: si la base ya existe, la recrea.
-- ============================================================
SET NOCOUNT ON;
USE master;

IF DB_ID('KentFoods_STAGE') IS NOT NULL
BEGIN
    ALTER DATABASE KentFoods_STAGE SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE KentFoods_STAGE;
END

-- Carpeta de datos: la misma donde está el archivo de KentFoods_DW; si no existe, la ruta por defecto de la instancia
DECLARE @dir nvarchar(260), @sql nvarchar(max);
SELECT @dir = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
FROM sys.master_files WHERE database_id = DB_ID('KentFoods_DW') AND type = 0;
IF @dir IS NULL SET @dir = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(260));

SET @sql = N'CREATE DATABASE KentFoods_STAGE
ON PRIMARY (NAME = N''KentFoods_STAGE'',     FILENAME = N''' + @dir + N'KentFoods_STAGE.mdf'',     SIZE = 16MB, FILEGROWTH = 16MB)
LOG ON      (NAME = N''KentFoods_STAGE_log'', FILENAME = N''' + @dir + N'KentFoods_STAGE_log.ldf'', SIZE = 8MB,  FILEGROWTH = 8MB);
ALTER DATABASE KentFoods_STAGE SET RECOVERY SIMPLE;';
EXEC sp_executesql @sql;
GO

USE KentFoods_STAGE;
GO

CREATE TABLE dbo.ST_CLIENTE (
    ClienteCodigo varchar(10)  NOT NULL,
    NombreEmpresa varchar(100) NOT NULL,
    Ciudad        varchar(50)  NULL,
    CodigoPostal  varchar(20)  NULL,
    Pais          varchar(50)  NULL
);

CREATE TABLE dbo.ST_PROVEEDOR (
    ProveedorID int          NOT NULL,
    Proveedor   varchar(100) NOT NULL,
    Ciudad      varchar(50)  NULL,
    Pais        varchar(50)  NULL
);

CREATE TABLE dbo.ST_TRANSPORTISTA (
    TransportistaID int          NOT NULL,
    Transportista   varchar(100) NOT NULL
);

CREATE TABLE dbo.ST_PRODUCTO (
    ProductoID      int          NOT NULL,
    NombreProducto  varchar(100) NOT NULL,
    ProveedorID     int          NOT NULL,
    CategoriaID     int          NOT NULL,
    NombreCategoria varchar(50)  NOT NULL
);

CREATE TABLE dbo.ST_EMPLEADO (
    EmpleadoID     int          NOT NULL,
    NombreEmpleado varchar(100) NOT NULL,
    Territorio     varchar(50)  NULL,
    Region         varchar(50)  NULL
);

CREATE TABLE dbo.ST_ORDEN (
    OrdenID         int         NOT NULL,
    ClienteCodigo   varchar(10) NOT NULL,
    EmpleadoID      int         NOT NULL,
    TransportistaID int         NULL,
    FechaOrden      date        NOT NULL,
    FechaEnvio      date        NULL
);

CREATE TABLE dbo.ST_DETALLE (
    OrdenID        int           NOT NULL,
    ProductoID     int           NOT NULL,
    PrecioUnitario decimal(18,2) NOT NULL,
    Cantidad       int           NOT NULL,
    Descuento      decimal(5,2)  NOT NULL
);

-- Bitácora de cargas (conteos por tabla y ejecución)
CREATE TABLE dbo.LOG_CARGA (
    LogID   int IDENTITY(1,1) PRIMARY KEY,
    Paquete varchar(100) NOT NULL,
    Tabla   varchar(100) NOT NULL,
    Filas   int          NOT NULL,
    Fecha   datetime     NOT NULL DEFAULT (GETDATE())
);
GO

-- Procedimiento de control del Stage: compara conteos y venta total Origen vs Stage,
-- registra el resultado en LOG_CARGA y falla (RAISERROR) si hay diferencias.
CREATE OR ALTER PROCEDURE dbo.SP_CONTROL_STAGE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @e int = 0;
    CREATE TABLE #ctl (tabla varchar(40), origen decimal(18,2), stage decimal(18,2));
    INSERT #ctl SELECT 'ST_CLIENTE',       (SELECT COUNT(*) FROM KentFoods.dbo.Clientes),        (SELECT COUNT(*) FROM dbo.ST_CLIENTE);
    INSERT #ctl SELECT 'ST_PROVEEDOR',     (SELECT COUNT(*) FROM KentFoods.dbo.Proveedores),     (SELECT COUNT(*) FROM dbo.ST_PROVEEDOR);
    INSERT #ctl SELECT 'ST_TRANSPORTISTA', (SELECT COUNT(*) FROM KentFoods.dbo.Transportistas),  (SELECT COUNT(*) FROM dbo.ST_TRANSPORTISTA);
    INSERT #ctl SELECT 'ST_PRODUCTO',      (SELECT COUNT(*) FROM KentFoods.dbo.Productos),       (SELECT COUNT(*) FROM dbo.ST_PRODUCTO);
    INSERT #ctl SELECT 'ST_EMPLEADO',      (SELECT COUNT(*) FROM KentFoods.dbo.Empleados),       (SELECT COUNT(*) FROM dbo.ST_EMPLEADO);
    INSERT #ctl SELECT 'ST_ORDEN',         (SELECT COUNT(*) FROM KentFoods.dbo.Ordenes),         (SELECT COUNT(*) FROM dbo.ST_ORDEN);
    INSERT #ctl SELECT 'ST_DETALLE',       (SELECT COUNT(*) FROM KentFoods.dbo.DetalleOrden),    (SELECT COUNT(*) FROM dbo.ST_DETALLE);
    INSERT #ctl SELECT 'unidades (ST_DETALLE)', (SELECT SUM(CAST(Cantidad AS bigint)) FROM KentFoods.dbo.DetalleOrden), (SELECT SUM(CAST(Cantidad AS bigint)) FROM dbo.ST_DETALLE);
    INSERT #ctl SELECT 'venta neta (ST_DETALLE)',
        (SELECT SUM(PrecioUnitario * Cantidad * (1 - Descuento)) FROM KentFoods.dbo.DetalleOrden),
        (SELECT SUM(PrecioUnitario * Cantidad * (1 - Descuento)) FROM dbo.ST_DETALLE);

    SELECT tabla, origen, stage, stage - origen AS diferencia,
           CASE WHEN ABS(stage - origen) <= CASE WHEN tabla LIKE '%venta%' THEN 1.00 ELSE 0 END THEN 'OK' ELSE 'DIFERENCIA' END AS estado
    FROM #ctl;

    SELECT @e = COUNT(*) FROM #ctl WHERE ABS(stage - origen) > CASE WHEN tabla LIKE '%venta%' THEN 1.00 ELSE 0 END;

    INSERT INTO dbo.LOG_CARGA (Paquete, Tabla, Filas)
    SELECT '01_ETL_KentFoods_OLTP_Stage', tabla, CAST(stage AS int) FROM #ctl WHERE tabla LIKE 'ST[_]%' AND tabla NOT LIKE '%(%';

    IF @e > 0 RAISERROR('SP_CONTROL_STAGE: %d controles con diferencias entre Origen y Stage.', 16, 1, @e);
END
GO
PRINT 'KentFoods_STAGE creada (tablas ST_*, LOG_CARGA y SP_CONTROL_STAGE).';
