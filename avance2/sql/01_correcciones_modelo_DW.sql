-- ============================================================
-- 01_correcciones_modelo_DW.sql  |  Correcciones al modelo dimensional (Avance 1) antes de la carga
-- Base: KentFoods_DW (restaurada desde KentFoods_DW.bak, tablas vacías)
--
-- CORRECCION 1: clave de Dim_Cliente
--   Origen : Clientes.ClienteID es nchar(10) alfanumérico (ej. 'ALFKI'), no numérico.
--   Modelo : Dim_Cliente.ClienteID y Fact_Ventas.id_cliente eran int -> la carga era imposible.
--   Solución: ClienteID pasa a ser clave sustituta (IDENTITY) y la clave de negocio
--             se conserva en ClienteCodigo (única).
-- Idempotente: si ya se aplicó, no hace nada.
-- ============================================================
SET NOCOUNT ON;
USE KentFoods_DW;

IF COL_LENGTH('dbo.Dim_Cliente', 'ClienteCodigo') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Fact_Ventas) OR EXISTS (SELECT 1 FROM dbo.Dim_Cliente)
    BEGIN
        RAISERROR('Dim_Cliente/Fact_Ventas contienen datos: no se recrea la dimension.', 16, 1);
        RETURN;
    END

    DECLARE @fk sysname, @sql nvarchar(400);
    SELECT @fk = fk.name
    FROM sys.foreign_keys fk
    WHERE fk.parent_object_id = OBJECT_ID('dbo.Fact_Ventas')
      AND fk.referenced_object_id = OBJECT_ID('dbo.Dim_Cliente');
    IF @fk IS NOT NULL
    BEGIN
        SET @sql = N'ALTER TABLE dbo.Fact_Ventas DROP CONSTRAINT ' + QUOTENAME(@fk);
        EXEC sp_executesql @sql;
    END

    DROP TABLE dbo.Dim_Cliente;

    CREATE TABLE dbo.Dim_Cliente (
        ClienteID     int IDENTITY(1,1) NOT NULL,
        ClienteCodigo varchar(10)  NOT NULL,
        NombreEmpresa varchar(100) NOT NULL,
        Ciudad        varchar(50)  NULL,
        CodigoPostal  varchar(20)  NULL,
        Pais          varchar(50)  NULL,
        CONSTRAINT PK_Dim_Cliente PRIMARY KEY (ClienteID),
        CONSTRAINT UQ_Dim_Cliente_Codigo UNIQUE (ClienteCodigo)
    );

    ALTER TABLE dbo.Fact_Ventas
        ADD CONSTRAINT FK_Fact_Ventas_Dim_Cliente
        FOREIGN KEY (id_cliente) REFERENCES dbo.Dim_Cliente (ClienteID);

    PRINT 'Correccion 1 aplicada: Dim_Cliente con clave sustituta ClienteID y clave de negocio ClienteCodigo.';
END
ELSE
    PRINT 'Correccion 1 ya estaba aplicada.';
