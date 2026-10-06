# Ejecuta los 5 paquetes de perfilamiento (Data Profiling Task) y deja los XML en ssis\KentFoods_Profiler\Resultados.
# Los paquetes guardan la ruta de salida de forma absoluta; este script la ajusta al lugar donde esta el repo en ESTE equipo.
# Uso:  powershell -ExecutionPolicy Bypass -File avance2\ejecutar_perfilamiento.ps1 [-ActualizarRutas]
#   -ActualizarRutas : ademas corrige las rutas en los .dtsx del repo (necesario para abrirlos y ejecutarlos con F5 en Visual Studio)
param([switch]$ActualizarRutas)
$ErrorActionPreference = 'Stop'
$repo   = Split-Path -Parent $PSScriptRoot
$proj   = Join-Path $repo 'avance2\ssis\KentFoods_Profiler'
$res    = Join-Path $proj 'Resultados'
$dtexec = 'C:\Program Files\Microsoft SQL Server\150\DTS\Binn\DTExec.exe'
New-Item -ItemType Directory -Force -Path $res | Out-Null

function Set-RutasSalida([string]$carpeta) {
    # reemplaza el prefijo de cada ruta ...\Resultados\<TABLA>_Profile.xml por la carpeta del repo actual
    $pref = $proj.Replace('$', '$$')
    foreach ($f in Get-ChildItem $carpeta -Filter '*.dtsx') {
        $t = Get-Content -Raw -Encoding UTF8 $f.FullName
        $n = [regex]::Replace($t, '(?<=DTS:ConnectionString=")[^"]*?(?=\\Resultados\\[^"\\]+_Profile\.xml")', $pref)
        if ($n -ne $t) { [IO.File]::WriteAllText($f.FullName, $n, (New-Object Text.UTF8Encoding($true))) }
    }
}

if ($ActualizarRutas) {
    Set-RutasSalida $proj
    Write-Host '[ok] rutas de los paquetes del repo actualizadas'
    $carpetaEjecucion = $proj
} else {
    # se ejecuta una copia temporal con las rutas corregidas, para no modificar archivos versionados
    $carpetaEjecucion = Join-Path $env:TEMP ('KentFoods_Profiler_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $carpetaEjecucion | Out-Null
    Copy-Item (Join-Path $proj '*.dtsx') $carpetaEjecucion
    Set-RutasSalida $carpetaEjecucion
}

foreach ($p in '01_Perfil_Ordenes','02_Perfil_Clientes','03_Perfil_Productos','04_Perfil_Empleados','05_Perfil_Transportistas') {
    $salida = & $dtexec /File (Join-Path $carpetaEjecucion "$p.dtsx") /Reporting EW 2>&1 | Out-String
    $ok = $salida -match 'DTSER_SUCCESS'
    Write-Host ("{0,-28} {1}" -f $p, $(if ($ok) { 'OK' } else { 'ERROR' }))
    if (-not $ok) { $salida; throw "Fallo $p" }
}
if (-not $ActualizarRutas) { Remove-Item $carpetaEjecucion -Recurse -Force }
Write-Host ("XML generados en {0}: {1}" -f $res, (Get-ChildItem $res -Filter '*_Profile.xml').Count)
Write-Host 'Abrirlos con Data Profile Viewer: C:\Program Files (x86)\Microsoft SQL Server\150\DTS\Binn\DataProfileViewer.exe'
