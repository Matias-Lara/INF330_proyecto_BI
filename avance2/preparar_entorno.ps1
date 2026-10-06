# Prepara el entorno SQL Server desde cero para el Avance 2 (idempotente):
#   1) restaura KentFoods (origen) y KentFoods_DW (modelo dimensional) desde bd\*.bak si no existen
#   2) aplica la correccion del modelo (Dim_Cliente con clave sustituta)
#   3) crea KentFoods_STAGE con sus tablas ST_* y SP_CONTROL_STAGE
#   4) crea SP_CONTROL_DW
# Uso:  powershell -ExecutionPolicy Bypass -File avance2\preparar_entorno.ps1 [-Servidor .] [-RutaDatos "E:\SQLData"]
param(
    [string]$Servidor = '.',
    [string]$RutaDatos = '',         # carpeta para los .mdf/.ldf al restaurar; vacio = ruta por defecto de la instancia
    [switch]$RecrearDW               # restaura KentFoods_DW desde el .bak aunque ya exista (pierde lo cargado)
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$bd   = Join-Path $repo 'bd'
$sql  = Join-Path $PSScriptRoot 'sql'

function Invoke-Sql([string]$query, [string]$db = 'master') {
    $o = sqlcmd -S $Servidor -E -C -W -b -h -1 -d $db -Q $query 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($o | Out-String) }
    return ($o | Out-String).Trim()
}
function Invoke-SqlFile([string]$file) {
    $o = sqlcmd -S $Servidor -E -C -W -b -f 65001 -i $file 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($o | Out-String) }
    $o | Where-Object { $_ -notmatch '^Changed database context' -and $_ } | ForEach-Object { Write-Host "   $_" }
}
function Restore-Bak([string]$dbName, [string]$bak, [bool]$forzar = $false) {
    if (-not $forzar -and (Invoke-Sql "SET NOCOUNT ON; SELECT DB_ID('$dbName')") -ne 'NULL') { Write-Host "[ok] $dbName ya existe"; return }
    if (-not (Test-Path $bak)) { throw "No se encontro $bak" }
    # El servicio de SQL Server debe poder leer el .bak; si la carpeta del repo no se lo permite, se usa una copia en su carpeta Backup
    [void](sqlcmd -S $Servidor -E -C -W -b -h -1 -Q "SET NOCOUNT ON; RESTORE HEADERONLY FROM DISK='$bak'" 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $dirBk = Invoke-Sql "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(260))"
        try { Copy-Item $bak $dirBk -Force -ErrorAction Stop }
        catch { throw "SQL Server no puede leer '$bak' y no se pudo copiar a '$dirBk'. Ejecute PowerShell como administrador o copie el .bak a una carpeta que el servicio pueda leer." }
        $bak = Join-Path $dirBk (Split-Path $bak -Leaf)
        Write-Host "[..] el servicio de SQL Server no puede leer la carpeta del repo; se usa una copia en $dirBk"
    }
    Write-Host "[..] restaurando $dbName desde $bak"
    $rutaDatos = $RutaDatos
    if (-not $rutaDatos) { $rutaDatos = Invoke-Sql "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(260))" }
    if (-not $rutaDatos.EndsWith('\')) { $rutaDatos += '\' }
    New-Item -ItemType Directory -Force -Path $rutaDatos | Out-Null
    # nombres logicos del backup
    $fl = sqlcmd -S $Servidor -E -C -W -h -1 -s "|" -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK='$bak'" 2>&1
    $files = $fl | Where-Object { $_ -match '\|' } | ForEach-Object { $c = $_ -split '\|'; [pscustomobject]@{ Logical = $c[0].Trim(); Type = $c[2].Trim() } }
    $move = ($files | ForEach-Object {
        $ext = if ($_.Type -eq 'L') { '.ldf' } else { '.mdf' }
        "MOVE '$($_.Logical)' TO '$rutaDatos$dbName$(if ($_.Type -eq 'L') { '_log' })$ext'"
    }) -join ', '
    [void](Invoke-Sql "RESTORE DATABASE [$dbName] FROM DISK='$bak' WITH $move, REPLACE")
    Write-Host "[ok] $dbName restaurada"
}

Write-Host '== Preparando entorno Kent Foods (Avance 2) =='
Restore-Bak 'KentFoods'    (Join-Path $bd 'KentFoods.bak')
Restore-Bak 'KentFoods_DW' (Join-Path $bd 'KentFoods_DW.bak') $RecrearDW.IsPresent
Write-Host '[..] correccion del modelo (Dim_Cliente)';  Invoke-SqlFile (Join-Path $sql '01_correcciones_modelo_DW.sql')
Write-Host '[..] creando KentFoods_STAGE';              Invoke-SqlFile (Join-Path $sql '02_crear_stage.sql')
Write-Host '[..] creando SP_CONTROL_DW';                Invoke-SqlFile (Join-Path $sql '03_crear_controles_DW.sql')
Write-Host '== Listo. Siguiente paso: powershell -File avance2\ejecutar_etl.ps1 =='
