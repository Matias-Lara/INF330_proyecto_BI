# Genera el proyecto SSIS KentFoods_ETL_SSIS (2 paquetes) usando la API de Integration Services 2019.
# Salida: avance2\ssis\KentFoods_ETL_SSIS\*.dtsx  +  .dtproj / .sln
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)          # raiz del repo
$ssis   = Join-Path $root 'avance2\ssis'
$projDir = Join-Path $ssis 'KentFoods_ETL_SSIS'
New-Item -ItemType Directory -Force -Path $projDir | Out-Null

$pub = 'Culture=neutral, PublicKeyToken=89845dcd8080cc91'
Add-Type -AssemblyName "Microsoft.SqlServer.ManagedDTS, Version=15.0.0.0, $pub"
Add-Type -AssemblyName "Microsoft.SqlServer.DTSPipelineWrap, Version=15.0.0.0, $pub"
$app = New-Object Microsoft.SqlServer.Dts.Runtime.Application

$CSFMT = 'Data Source=.;Initial Catalog={0};Provider=MSOLEDBSQL.1;Integrated Security=SSPI;Auto Translate=False;Trust Server Certificate=True;'

# ---------------------------------------------------------------- utilidades
function New-Package([string]$name) {
    $p = New-Object Microsoft.SqlServer.Dts.Runtime.Package
    $p.Name = $name
    $p.ProtectionLevel = [Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]::DontSaveSensitive
    $p.PackageType = [Microsoft.SqlServer.Dts.Runtime.DTSPackageType]::DTSDesigner100
    $p.CreatorName = 'Grupo 7'
    return $p
}
function Add-Conn($pkg, [string]$name, [string]$db) {
    $cm = $pkg.Connections.Add('OLEDB')
    $cm.Name = $name
    $cm.ConnectionString = ($CSFMT -f $db)
    return $cm
}
function Add-SqlTask($pkg, [string]$name, [string]$desc, $cm, [string]$sql) {
    $th = [Microsoft.SqlServer.Dts.Runtime.TaskHost]$pkg.Executables.Add('STOCK:SQLTask')
    $th.Name = $name
    $th.Description = $desc
    $th.Properties['Connection'].SetValue($th, $cm.ID)
    $th.Properties['SqlStatementSource'].SetValue($th, $sql)
    return $th
}
$gac = 'C:\Windows\Microsoft.NET\assembly'
$refs = @(
    "$gac\GAC_MSIL\Microsoft.SqlServer.ManagedDTS\v4.0_15.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.ManagedDTS.dll",
    "$gac\GAC_MSIL\Microsoft.SqlServer.DTSPipelineWrap\v4.0_15.0.0.0__89845dcd8080cc91\Microsoft.SQLServer.DTSPipelineWrap.dll",
    "$gac\GAC_64\Microsoft.SqlServer.DTSRuntimeWrap\v4.0_15.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.DTSRuntimeWrap.dll"
)
Add-Type -TypeDefinition (Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'DftBuilder.cs')) -ReferencedAssemblies $refs
function Add-Dft($pkg, [string]$name, [string]$desc, $srcCm, [string]$sql, $dstCm, [string]$table) {
    $n = 0
    $th = [EtlSupport.DftBuilder]::Add($pkg, $name, $desc, $srcCm, $sql, $dstCm, $table, [ref]$n)
    Write-Host ("   {0}: {1} columnas mapeadas -> {2}" -f $name, $n, $table)
    return $th
}
function Join-Chain($pkg, $tasks) {
    for ($i = 0; $i -lt $tasks.Count - 1; $i++) { [void]$pkg.PrecedenceConstraints.Add($tasks[$i], $tasks[$i + 1]) }
}
function Save-Package($pkg, [string]$path) {
    $app.SaveToXml($path, $pkg, $null)
    # layout en grilla de 2 columnas (igual que los ejemplos del profesor)
    [xml]$x = Get-Content -Raw -Encoding UTF8 $path
    $ns = New-Object System.Xml.XmlNamespaceManager($x.NameTable)
    $ns.AddNamespace('DTS', 'www.microsoft.com/SqlServer/Dts')
    $nodes = New-Object System.Text.StringBuilder
    $i = 0
    foreach ($e in $x.SelectNodes('/DTS:Executable/DTS:Executables/DTS:Executable', $ns)) {
        $ref = $e.GetAttribute('refId', 'www.microsoft.com/SqlServer/Dts')
        $col = $i % 2; $row = [math]::Floor($i / 2)
        $left = 30 + 340 * $col; $top = 30 + 78 * $row
        [void]$nodes.Append("<NodeLayout Size=`"290,42.6666666667`" Id=`"$ref`" TopLeft=`"$left,$top`" />")
        $i++
    }
    $layout = '<?xml version="1.0"?><Objects Version="8"><Package design-time-name="Package"><LayoutInfo><GraphLayout Capacity="64" xmlns="clr-namespace:Microsoft.SqlServer.IntegrationServices.Designer.Model.Serialization;assembly=Microsoft.SqlServer.IntegrationServices.Graph">' + $nodes.ToString() + '</GraphLayout></LayoutInfo></Package></Objects>'
    $dt = $x.CreateElement('DTS', 'DesignTimeProperties', 'www.microsoft.com/SqlServer/Dts')
    [void]$dt.AppendChild($x.CreateCDataSection($layout))
    [void]$x.DocumentElement.AppendChild($dt)
    $x.Save($path)
}

# ================================================================ PAQUETE 01: OLTP -> STAGE
Write-Host '== 01_ETL_KentFoods_OLTP_Stage =='
$p1 = New-Package '01_ETL_KentFoods_OLTP_Stage'
$cmO = Add-Conn $p1 'KentFoods_OLTP'  'KentFoods'
$cmS = Add-Conn $p1 'KentFoods_STAGE' 'KentFoods_STAGE'

$t = @()
$t += Add-SqlTask $p1 '00_Limpiar_STAGE' 'Vacía las tablas del área Stage antes de una carga completa' $cmS @'
TRUNCATE TABLE dbo.ST_DETALLE;
TRUNCATE TABLE dbo.ST_ORDEN;
TRUNCATE TABLE dbo.ST_EMPLEADO;
TRUNCATE TABLE dbo.ST_PRODUCTO;
TRUNCATE TABLE dbo.ST_TRANSPORTISTA;
TRUNCATE TABLE dbo.ST_PROVEEDOR;
TRUNCATE TABLE dbo.ST_CLIENTE;
'@

$t += Add-Dft $p1 '01_DFT_CLIENTE' 'KentFoods.Clientes -> ST_CLIENTE (clave alfanumérica a varchar, TRIM de textos)' $cmO @'
SELECT CAST(LTRIM(RTRIM(ClienteID)) AS varchar(10))   AS ClienteCodigo,
       CAST(LTRIM(RTRIM(Empresa)) AS varchar(100))    AS NombreEmpresa,
       CAST(LTRIM(RTRIM(Ciudad)) AS varchar(50))      AS Ciudad,
       CAST(LTRIM(RTRIM(CodigoPostal)) AS varchar(20)) AS CodigoPostal,
       CAST(LTRIM(RTRIM(Pais)) AS varchar(50))        AS Pais
FROM dbo.Clientes;
'@ $cmS 'ST_CLIENTE'

$t += Add-Dft $p1 '02_DFT_PROVEEDOR' 'KentFoods.Proveedores -> ST_PROVEEDOR' $cmO @'
SELECT CAST(ProveedorID AS int)                     AS ProveedorID,
       CAST(LTRIM(RTRIM(Proveedor)) AS varchar(100)) AS Proveedor,
       CAST(LTRIM(RTRIM(Ciudad)) AS varchar(50))     AS Ciudad,
       CAST(LTRIM(RTRIM(Pais)) AS varchar(50))       AS Pais
FROM dbo.Proveedores;
'@ $cmS 'ST_PROVEEDOR'

$t += Add-Dft $p1 '03_DFT_TRANSPORTISTA' 'KentFoods.Transportistas -> ST_TRANSPORTISTA' $cmO @'
SELECT CAST(TransportistaID AS int)                      AS TransportistaID,
       CAST(LTRIM(RTRIM(Transportista)) AS varchar(100)) AS Transportista
FROM dbo.Transportistas;
'@ $cmS 'ST_TRANSPORTISTA'

$t += Add-Dft $p1 '04_DFT_PRODUCTO' 'KentFoods.Productos + Categorias -> ST_PRODUCTO (categoría desnormalizada)' $cmO @'
SELECT CAST(P.ProductoID AS int)                      AS ProductoID,
       CAST(LTRIM(RTRIM(P.Producto)) AS varchar(100))  AS NombreProducto,
       CAST(P.ProveedorID AS int)                      AS ProveedorID,
       CAST(P.CategoriaID AS int)                      AS CategoriaID,
       CAST(LTRIM(RTRIM(C.Categoria)) AS varchar(50))  AS NombreCategoria
FROM dbo.Productos AS P
INNER JOIN dbo.Categorias AS C
        ON C.CategoriaID = P.CategoriaID;
'@ $cmS 'ST_PRODUCTO'

$t += Add-Dft $p1 '05_DFT_EMPLEADO' 'Empleados + Territorios + Regiones -> ST_EMPLEADO (un territorio por empleado: menor TerritorioID)' $cmO @'
SELECT CAST(E.EmpleadoID AS int)                                                    AS EmpleadoID,
       CAST(LTRIM(RTRIM(E.Nombre)) + ' ' + LTRIM(RTRIM(E.Apellido)) AS varchar(100)) AS NombreEmpleado,
       CAST(RTRIM(T.Territorio) AS varchar(50))                                      AS Territorio,
       CAST(RTRIM(R.Region) AS varchar(50))                                          AS Region
FROM dbo.Empleados AS E
OUTER APPLY (SELECT TOP (1) TE.TerritorioID
             FROM dbo.TerritoriosEmpleados AS TE
             WHERE TE.EmpleadoID = E.EmpleadoID
             ORDER BY TE.TerritorioID) AS X
LEFT JOIN dbo.Territorios AS T ON T.TerritorioID = X.TerritorioID
LEFT JOIN dbo.Regiones    AS R ON R.RegionID     = T.RegionID;
'@ $cmS 'ST_EMPLEADO'

$t += Add-Dft $p1 '06_DFT_ORDEN' 'KentFoods.Ordenes -> ST_ORDEN (fechas a tipo date, clave de cliente depurada)' $cmO @'
SELECT CAST(OrdenID AS int)                       AS OrdenID,
       CAST(LTRIM(RTRIM(ClienteID)) AS varchar(10)) AS ClienteCodigo,
       CAST(EmpleadoID AS int)                    AS EmpleadoID,
       CAST(EnviadoPor AS int)                    AS TransportistaID,
       CAST(FechaOrden AS date)                   AS FechaOrden,
       CAST(FechaEnvio AS date)                   AS FechaEnvio
FROM dbo.Ordenes;
'@ $cmS 'ST_ORDEN'

$t += Add-Dft $p1 '07_DFT_DETALLE' 'KentFoods.DetalleOrden -> ST_DETALLE (descuento real a decimal(5,2), precio money a decimal)' $cmO @'
SELECT CAST(OrdenID AS int)                          AS OrdenID,
       CAST(ProductoID AS int)                       AS ProductoID,
       CAST(PrecioUnitario AS decimal(18,2))         AS PrecioUnitario,
       CAST(Cantidad AS int)                         AS Cantidad,
       CAST(ROUND(Descuento, 2) AS decimal(5,2))     AS Descuento
FROM dbo.DetalleOrden;
'@ $cmS 'ST_DETALLE'

$t += Add-SqlTask $p1 '08_SQL_Control_STAGE' 'Ejecuta SP_CONTROL_STAGE: compara conteos, unidades y venta total Origen vs Stage y registra la carga en LOG_CARGA' $cmS @'
EXEC dbo.SP_CONTROL_STAGE;
'@

Join-Chain $p1 $t
Save-Package $p1 (Join-Path $projDir '01_ETL_KentFoods_OLTP_Stage.dtsx')

# ================================================================ PAQUETE 02: STAGE -> DW
Write-Host '== 02_ETL_KentFoods_Stage_DW =='
$p2 = New-Package '02_ETL_KentFoods_Stage_DW'
$cmS2 = Add-Conn $p2 'KentFoods_STAGE' 'KentFoods_STAGE'
$cmD2 = Add-Conn $p2 'KentFoods_DW'    'KentFoods_DW'

$u = @()
$u += Add-SqlTask $p2 '00_SQL_Verificar_Precondiciones' 'Verifica que el Stage tenga datos (si está vacío, falta ejecutar el paquete 01)' $cmD2 @'
IF NOT EXISTS (SELECT 1 FROM KentFoods_STAGE.dbo.ST_ORDEN) OR NOT EXISTS (SELECT 1 FROM KentFoods_STAGE.dbo.ST_DETALLE)
    RAISERROR('El Stage está vacío: ejecute primero 01_ETL_KentFoods_OLTP_Stage.', 16, 1);
'@

$u += Add-Dft $p2 '01_DFT_Dim_Tiempo_Nuevas' 'Genera el calendario completo (años cubiertos por las órdenes) e inserta solo las fechas que no existen -> Dim_Tiempo' $cmS2 @'
WITH R AS (
    SELECT DATEFROMPARTS(YEAR(MIN(D)), 1, 1)   AS Ini,
           DATEFROMPARTS(YEAR(MAX(D)), 12, 31) AS Fin
    FROM (SELECT FechaOrden AS D FROM dbo.ST_ORDEN
          UNION ALL
          SELECT FechaEnvio FROM dbo.ST_ORDEN WHERE FechaEnvio IS NOT NULL) AS X
),
N AS (
    SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects AS a CROSS JOIN sys.all_objects AS b
)
SELECT CAST(CONVERT(char(8), F.Fecha, 112) AS int) AS FechaKey,
       F.Fecha                                     AS Fecha,
       DAY(F.Fecha)                                AS Dia,
       MONTH(F.Fecha)                              AS Mes,
       DATEPART(QUARTER, F.Fecha)                  AS Trimestre,
       YEAR(F.Fecha)                               AS Anio
FROM N
CROSS JOIN R
CROSS APPLY (SELECT DATEADD(DAY, N.n, R.Ini) AS Fecha) AS F
WHERE N.n <= DATEDIFF(DAY, R.Ini, R.Fin)
  AND NOT EXISTS (SELECT 1 FROM KentFoods_DW.dbo.Dim_Tiempo AS T
                  WHERE T.FechaKey = CAST(CONVERT(char(8), F.Fecha, 112) AS int));
'@ $cmD2 'Dim_Tiempo'

$u += Add-SqlTask $p2 '02_SQL_Actualizar_Dim_Transportista' 'Actualiza los transportistas existentes cuyo nombre cambió' $cmD2 @'
UPDATE D SET D.Transportista = S.Transportista
FROM dbo.Dim_Transportista AS D
INNER JOIN KentFoods_STAGE.dbo.ST_TRANSPORTISTA AS S ON S.TransportistaID = D.TransportistaID
WHERE EXISTS (SELECT S.Transportista EXCEPT SELECT D.Transportista);
'@
$u += Add-Dft $p2 '03_DFT_Dim_Transportista_Nuevos' 'ST_TRANSPORTISTA -> Dim_Transportista (solo transportistas nuevos)' $cmS2 @'
SELECT S.TransportistaID, S.Transportista
FROM dbo.ST_TRANSPORTISTA AS S
WHERE NOT EXISTS (SELECT 1 FROM KentFoods_DW.dbo.Dim_Transportista AS D WHERE D.TransportistaID = S.TransportistaID);
'@ $cmD2 'Dim_Transportista'

$u += Add-SqlTask $p2 '04_SQL_Actualizar_Dim_Proveedor' 'Actualiza los proveedores existentes cuyos atributos cambiaron' $cmD2 @'
UPDATE D SET D.Proveedor = S.Proveedor, D.Ciudad = S.Ciudad, D.Pais = S.Pais
FROM dbo.Dim_Proveedor AS D
INNER JOIN KentFoods_STAGE.dbo.ST_PROVEEDOR AS S ON S.ProveedorID = D.ProveedorID
WHERE EXISTS (SELECT S.Proveedor, S.Ciudad, S.Pais EXCEPT SELECT D.Proveedor, D.Ciudad, D.Pais);
'@
$u += Add-Dft $p2 '05_DFT_Dim_Proveedor_Nuevos' 'ST_PROVEEDOR -> Dim_Proveedor (solo proveedores nuevos)' $cmS2 @'
SELECT S.ProveedorID, S.Proveedor, S.Ciudad, S.Pais
FROM dbo.ST_PROVEEDOR AS S
WHERE NOT EXISTS (SELECT 1 FROM KentFoods_DW.dbo.Dim_Proveedor AS D WHERE D.ProveedorID = S.ProveedorID);
'@ $cmD2 'Dim_Proveedor'

$u += Add-SqlTask $p2 '06_SQL_Actualizar_Dim_Producto' 'Actualiza los productos existentes cuyos atributos cambiaron' $cmD2 @'
UPDATE D SET D.NombreProducto = S.NombreProducto, D.CategoriaID = S.CategoriaID, D.NombreCategoria = S.NombreCategoria
FROM dbo.Dim_Producto AS D
INNER JOIN KentFoods_STAGE.dbo.ST_PRODUCTO AS S ON S.ProductoID = D.ProductoID
WHERE EXISTS (SELECT S.NombreProducto, S.CategoriaID, S.NombreCategoria EXCEPT SELECT D.NombreProducto, D.CategoriaID, D.NombreCategoria);
'@
$u += Add-Dft $p2 '07_DFT_Dim_Producto_Nuevos' 'ST_PRODUCTO -> Dim_Producto (solo productos nuevos)' $cmS2 @'
SELECT S.ProductoID, S.NombreProducto, S.CategoriaID, S.NombreCategoria
FROM dbo.ST_PRODUCTO AS S
WHERE NOT EXISTS (SELECT 1 FROM KentFoods_DW.dbo.Dim_Producto AS D WHERE D.ProductoID = S.ProductoID);
'@ $cmD2 'Dim_Producto'

$u += Add-SqlTask $p2 '08_SQL_Actualizar_Dim_Cliente' 'Actualiza los clientes existentes (por clave de negocio ClienteCodigo) cuyos atributos cambiaron' $cmD2 @'
UPDATE D SET D.NombreEmpresa = S.NombreEmpresa, D.Ciudad = S.Ciudad, D.CodigoPostal = S.CodigoPostal, D.Pais = S.Pais
FROM dbo.Dim_Cliente AS D
INNER JOIN KentFoods_STAGE.dbo.ST_CLIENTE AS S ON S.ClienteCodigo = D.ClienteCodigo
WHERE EXISTS (SELECT S.NombreEmpresa, S.Ciudad, S.CodigoPostal, S.Pais EXCEPT SELECT D.NombreEmpresa, D.Ciudad, D.CodigoPostal, D.Pais);
'@
$u += Add-Dft $p2 '09_DFT_Dim_Cliente_Nuevos' 'ST_CLIENTE -> Dim_Cliente (solo clientes nuevos; SQL Server genera la clave sustituta ClienteID)' $cmS2 @'
SELECT S.ClienteCodigo, S.NombreEmpresa, S.Ciudad, S.CodigoPostal, S.Pais
FROM dbo.ST_CLIENTE AS S
WHERE NOT EXISTS (SELECT 1 FROM KentFoods_DW.dbo.Dim_Cliente AS D WHERE D.ClienteCodigo = S.ClienteCodigo);
'@ $cmD2 'Dim_Cliente'

$u += Add-SqlTask $p2 '10_SQL_Actualizar_Dim_Empleado' 'Actualiza los empleados existentes cuyos atributos cambiaron' $cmD2 @'
UPDATE D SET D.NombreEmpleado = S.NombreEmpleado, D.Territorio = S.Territorio, D.Region = S.Region
FROM dbo.Dim_Empleado AS D
INNER JOIN KentFoods_STAGE.dbo.ST_EMPLEADO AS S ON S.EmpleadoID = D.EmpleadoID
WHERE EXISTS (SELECT S.NombreEmpleado, S.Territorio, S.Region EXCEPT SELECT D.NombreEmpleado, D.Territorio, D.Region);
'@
$u += Add-Dft $p2 '11_DFT_Dim_Empleado_Nuevos' 'ST_EMPLEADO -> Dim_Empleado (solo empleados nuevos)' $cmS2 @'
SELECT S.EmpleadoID, S.NombreEmpleado, S.Territorio, S.Region
FROM dbo.ST_EMPLEADO AS S
WHERE NOT EXISTS (SELECT 1 FROM KentFoods_DW.dbo.Dim_Empleado AS D WHERE D.EmpleadoID = S.EmpleadoID);
'@ $cmD2 'Dim_Empleado'

$u += Add-SqlTask $p2 '12_SQL_Actualizar_Envios_Pendientes' 'Completa fecha de envío, días y transportista en los hechos que estaban pendientes de despacho' $cmD2 @'
UPDATE F
SET F.id_fecha_envio   = CAST(CONVERT(char(8), O.FechaEnvio, 112) AS int),
    F.dias_envio       = DATEDIFF(DAY, O.FechaOrden, O.FechaEnvio),
    F.id_transportista = O.TransportistaID
FROM dbo.Fact_Ventas AS F
INNER JOIN KentFoods_STAGE.dbo.ST_ORDEN AS O ON O.OrdenID = F.id_orden
WHERE F.id_fecha_envio IS NULL
  AND O.FechaEnvio IS NOT NULL;
'@

$u += Add-Dft $p2 '13_DFT_Fact_Ventas_Nuevas' 'ST_DETALLE + ST_ORDEN + ST_PRODUCTO -> Fact_Ventas (solo órdenes nuevas; claves de fecha, clave sustituta de cliente, monto_neto y dias_envio)' $cmS2 @'
SELECT D.OrdenID                                               AS id_orden,
       D.ProductoID                                            AS id_producto,
       CAST(CONVERT(char(8), O.FechaOrden, 112) AS int)        AS id_fecha_orden,
       CAST(CONVERT(char(8), O.FechaEnvio, 112) AS int)        AS id_fecha_envio,
       C.ClienteID                                             AS id_cliente,
       O.TransportistaID                                       AS id_transportista,
       O.EmpleadoID                                            AS id_empleado,
       P.ProveedorID                                           AS id_proveedor,
       D.Cantidad                                              AS cantidad,
       D.PrecioUnitario                                        AS precio_unitario,
       D.Descuento                                             AS descuento,
       CAST(ROUND(D.PrecioUnitario * D.Cantidad * (1 - D.Descuento), 2) AS decimal(18,2)) AS monto_neto,
       DATEDIFF(DAY, O.FechaOrden, O.FechaEnvio)               AS dias_envio
FROM dbo.ST_DETALLE AS D
INNER JOIN dbo.ST_ORDEN    AS O ON O.OrdenID    = D.OrdenID
INNER JOIN dbo.ST_PRODUCTO AS P ON P.ProductoID = D.ProductoID
INNER JOIN KentFoods_DW.dbo.Dim_Cliente AS C ON C.ClienteCodigo = O.ClienteCodigo
WHERE D.OrdenID > (SELECT ISNULL(MAX(id_orden), 0) FROM KentFoods_DW.dbo.Fact_Ventas);
'@ $cmD2 'Fact_Ventas'

$u += Add-SqlTask $p2 '14_SQL_Control_DW' 'Ejecuta SP_CONTROL_DW: compara Stage vs DW (conteos, venta, envíos pendientes, huérfanos) y registra la carga en LOG_CARGA' $cmD2 @'
EXEC dbo.SP_CONTROL_DW;
'@

Join-Chain $p2 $u
Save-Package $p2 (Join-Path $projDir '02_ETL_KentFoods_Stage_DW.dtsx')

# ================================================================ archivos de proyecto
$guidProj = '{7C1E5A52-3F0B-4B8E-9D3A-1F6A2E4B9C10}'
$guidSln  = '{3B8D2F77-5A41-4C9E-8E0B-6D1C7A9F2E55}'
$dtproj = @"
<?xml version="1.0" encoding="utf-8"?>
<Project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><DeploymentModel>Package</DeploymentModel><ProductVersion>15.0.2000.166</ProductVersion><SchemaVersion>9.0.1.0</SchemaVersion><State>`$base64`$PFNvdXJjZUNvbnRyb2xJbmZvIHhtbG5zOnhzZD0iaHR0cDovL3d3dy53My5vcmcvMjAwMS9YTUxTY2hlbWEiIHhtbG5zOnhzaT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS9YTUxTY2hlbWEtaW5zdGFuY2UiPg0KICA8RW5hYmxlZD5mYWxzZTwvRW5hYmxlZD4NCiAgPFByb2plY3ROYW1lPjwvUHJvamVjdE5hbWU+DQogIDxBdXhQYXRoPjwvQXV4UGF0aD4NCiAgPExvY2FsUGF0aD48L0xvY2FsUGF0aD4NCiAgPFByb3ZpZGVyPjwvUHJvdmlkZXI+DQo8L1NvdXJjZUNvbnRyb2xJbmZvPg==</State><Database><Name>KentFoods_ETL_SSIS.database</Name><FullPath>KentFoods_ETL_SSIS.database</FullPath></Database><DataSources /><DataSourceViews /><DeploymentModelSpecificContent><Manifest><DTSPackages><DtsPackage FormatVersion="8"><Name>01_ETL_KentFoods_OLTP_Stage.dtsx</Name><FullPath>01_ETL_KentFoods_OLTP_Stage.dtsx</FullPath><References /></DtsPackage><DtsPackage FormatVersion="8"><Name>02_ETL_KentFoods_Stage_DW.dtsx</Name><FullPath>02_ETL_KentFoods_Stage_DW.dtsx</FullPath><References /></DtsPackage></DTSPackages></Manifest></DeploymentModelSpecificContent><ControlFlowParts /><Miscellaneous /><Configurations><Configuration><Name>Development</Name><Options><OutputPath>bin</OutputPath><ConnectionMappings /><ConnectionProviderMappings /><ConnectionSecurityMappings /><DatabaseStorageLocations /><TargetServerVersion>SQLServer2019</TargetServerVersion><AzureMode>false</AzureMode><LinkedAzureTenantId /><LinkedAzureAccountId /><LinkedAzureSSISIR /><LinkedAzureStorage /><RemoteExecutionFolder /><ParameterConfigurationValues /></Options></Configuration></Configurations></Project>
"@
[IO.File]::WriteAllText((Join-Path $projDir 'KentFoods_ETL_SSIS.dtproj'), $dtproj, (New-Object Text.UTF8Encoding($true)))

$database = '<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:ddl2="http://schemas.microsoft.com/analysisservices/2003/engine/2" xmlns:ddl2_2="http://schemas.microsoft.com/analysisservices/2003/engine/2/2" xmlns:ddl100_100="http://schemas.microsoft.com/analysisservices/2008/engine/100/100" xmlns:ddl200="http://schemas.microsoft.com/analysisservices/2010/engine/200" xmlns:ddl200_200="http://schemas.microsoft.com/analysisservices/2010/engine/200/200" xmlns:ddl300="http://schemas.microsoft.com/analysisservices/2011/engine/300" xmlns:ddl300_300="http://schemas.microsoft.com/analysisservices/2011/engine/300/300" xmlns:ddl400="http://schemas.microsoft.com/analysisservices/2012/engine/400" xmlns:ddl400_400="http://schemas.microsoft.com/analysisservices/2012/engine/400/400" xmlns:ddl500="http://schemas.microsoft.com/analysisservices/2013/engine/500" xmlns:ddl500_500="http://schemas.microsoft.com/analysisservices/2013/engine/500/500" xmlns:dwd="http://schemas.microsoft.com/DataWarehouse/Designer/1.0" dwd:design-time-name="b3a4c1d2-6e7f-4a8b-9c0d-1e2f3a4b5c6d" xmlns="http://schemas.microsoft.com/analysisservices/2003/engine"><ID>KentFoods_ETL_SSIS</ID><Name>KentFoods_ETL_SSIS</Name><CreatedTimestamp>0001-01-01T00:00:00Z</CreatedTimestamp><LastSchemaUpdate>0001-01-01T00:00:00Z</LastSchemaUpdate><LastProcessed>0001-01-01T00:00:00Z</LastProcessed><State>Unprocessed</State><LastUpdate>0001-01-01T00:00:00Z</LastUpdate><DataSourceImpersonationInfo><ImpersonationMode>Default</ImpersonationMode><ImpersonationInfoSecurity>Unchanged</ImpersonationInfoSecurity></DataSourceImpersonationInfo></Database>'
[IO.File]::WriteAllText((Join-Path $projDir 'KentFoods_ETL_SSIS.database'), $database, (New-Object Text.UTF8Encoding($true)))
[IO.File]::WriteAllText((Join-Path $projDir 'Project.params'), "<?xml version=`"1.0`"?>`r`n<SSIS:Parameters xmlns:SSIS=`"www.microsoft.com/SqlServer/SSIS`" />", (New-Object Text.UTF8Encoding($true)))

$sln = @"
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 16
VisualStudioVersion = 16.0.31624.102
MinimumVisualStudioVersion = 10.0.40219.1
Project("{159641D6-6404-4A2A-AE62-294DE0FE8301}") = "KentFoods_ETL_SSIS", "KentFoods_ETL_SSIS\KentFoods_ETL_SSIS.dtproj", "$guidProj"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Development|Default = Development|Default
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		$guidProj.Development|Default.ActiveCfg = Development
		$guidProj.Development|Default.Build.0 = Development
	EndGlobalSection
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
	GlobalSection(ExtensibilityGlobals) = postSolution
		SolutionGuid = $guidSln
	EndGlobalSection
EndGlobal
"@
[IO.File]::WriteAllText((Join-Path $ssis 'KentFoods_ETL_SSIS.sln'), $sln, (New-Object Text.UTF8Encoding($true)))
Write-Host 'Listo.'



