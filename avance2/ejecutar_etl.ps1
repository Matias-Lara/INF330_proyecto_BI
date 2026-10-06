# Ejecuta la ETL completa por consola (equivalente a ejecutar los 2 paquetes en Visual Studio) y muestra los controles.
# Uso:  powershell -ExecutionPolicy Bypass -File avance2\ejecutar_etl.ps1 [-ReiniciarDW] [-Servidor .]
#   -ReiniciarDW : deja el DW vacio antes de cargar (prueba limpia)
param(
    [string]$Servidor = '.',
    [switch]$ReiniciarDW
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$proj = Join-Path $repo 'avance2\ssis\KentFoods_ETL_SSIS'
$dtexec = 'C:\Program Files\Microsoft SQL Server\150\DTS\Binn\DTExec.exe'

function Run-Package([string]$name) {
    $salida = & $dtexec /File (Join-Path $proj "$name.dtsx") /Reporting EW 2>&1 | Out-String
    $ok = $salida -match 'DTSER_SUCCESS'
    $t = ([regex]::Match($salida, 'Elapsed:\s+([\d\.]+) seconds')).Groups[1].Value
    Write-Host ("{0,-34} {1}  ({2} s)" -f $name, $(if ($ok) { 'OK' } else { 'ERROR' }), $t)
    if (-not $ok) { $salida; throw "Fallo el paquete $name" }
}

if ($ReiniciarDW) {
    Write-Host '[..] reiniciando DW'
    sqlcmd -S $Servidor -E -C -W -b -f 65001 -i (Join-Path $repo 'avance2\sql\04_reiniciar_DW.sql') | Out-Null
}
Run-Package '01_ETL_KentFoods_OLTP_Stage'
Run-Package '02_ETL_KentFoods_Stage_DW'
Write-Host '--- Resultado de los controles (SP_CONTROL_DW)'
sqlcmd -S $Servidor -E -C -W -s '|' -Q "SET NOCOUNT ON; EXEC KentFoods_DW.dbo.SP_CONTROL_DW"
