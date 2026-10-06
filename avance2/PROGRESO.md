# PROGRESO — Avance 2 (Proceso ETL) · Grupo 7

Última actualización: 06-10-2026. Presentación: **miércoles 07-10-2026, 11:20** (10 min + demo en vivo, 5 min de preguntas).

## Estado
| Entregable | Estado |
|---|---|
| Entorno SQL Server (origen, Stage, DW) | ✅ Hecho y verificado (bases en `E:\SQLData`) |
| Perfilamiento con Data Profiling Task (5 paquetes, 11 tablas, XML generados) | ✅ Hecho |
| Paquete SSIS 01: Origen → Stage | ✅ Hecho, ejecutado con éxito (dtexec) y compila en VS 2019 |
| Paquete SSIS 02: Stage → DW (dimensiones update+insert, hechos incremental) | ✅ Hecho, ejecutado con éxito y probado con cambios reales en el origen |
| Controles de carga (`SP_CONTROL_STAGE`, `SP_CONTROL_DW`) y validación | ✅ 17 controles en OK |
| Respaldos del DW cargado y del Stage | ✅ `respaldos\` |
| Texto del informe (secciones 1 a 5) | ✅ `informe\informe_avance2_texto.md` — falta pegarlo en el Doc y agregar capturas |
| Guion de demo y preguntas probables | ✅ `demo\guion_demo.md` |
| Diapositivas | ⬜ Pendiente (estructura sugerida en el guion) |
| Capturas de pantalla (9 figuras) | ⬜ **Las debe tomar el equipo** en Visual Studio/SSMS (lista en `informe\NOTAS_para_el_equipo.md`) |
| Verificación en Visual Studio por una persona (abrir `.sln`, F5 en cada paquete) | ⬜ Pendiente (se verificó compilación con `devenv /Build` y ejecución con `dtexec`) |

## Cómo ejecutar
```powershell
# entorno limpio desde cero (restaura el DW original, crea el Stage, controles)  — ~10 s
powershell -ExecutionPolicy Bypass -File avance2\preparar_entorno.ps1 -RecrearDW
# ETL completa por consola (equivale a ejecutar los dos paquetes en Visual Studio) + controles
powershell -ExecutionPolicy Bypass -File avance2\ejecutar_etl.ps1
# o abrir en Visual Studio 2019:  avance2\ssis\KentFoods_ETL_SSIS.sln   (paquetes 01 y 02)
#                                 avance2\ssis\KentFoods_Profiler.sln  (perfilamiento)
```
### Levantar todo en otro PC (o en otra sesión de Claude)
1. Requisitos: SQL Server 2019 como instancia por defecto (servidor `.`), Integration Services y `sqlcmd`; Visual Studio 2019 + extensión *Integration Services Projects* solo si se quieren abrir los paquetes (ejecutarlos por consola no lo necesita). Manual de instalación en `material_curso\`.
2. `git clone` del repo (trae `bd\*.bak`, los scripts, los paquetes y los respaldos).
3. Los dos comandos de arriba (`preparar_entorno.ps1 -RecrearDW` y `ejecutar_etl.ps1`). Si SQL Server no puede leer la carpeta del repo, el script copia el `.bak` a la carpeta `Backup` de la instancia (puede requerir PowerShell como administrador).
4. Perfilamiento (opcional): `powershell -ExecutionPolicy Bypass -File avance2\ejecutar_perfilamiento.ps1` (usa una copia temporal con las rutas de ese equipo). Para abrir esos paquetes en Visual Studio, agregar `-ActualizarRutas` (modifica los `.dtsx` del repo: no commitear ese cambio).
5. Los paquetes SSIS 01 y 02 no tienen rutas propias del equipo (`Data Source=.`, autenticación de Windows).

Resultado esperado: 2.155 líneas de hechos, 91 clientes, 29 proveedores, 3 transportistas, 77 productos, 9 empleados, 1.096 días; venta $1.265.793,29 (origen $1.265.793,04; $0,25 por redondeo); 73 líneas sin fecha de envío; todos los controles en OK.

## Estructura de `avance2\`
- `sql\` — `00_perfilamiento.sql`, `01_correcciones_modelo_DW.sql`, `02_crear_stage.sql`, `03_crear_controles_DW.sql`, `04_reiniciar_DW.sql`, `90_validacion.sql`.
- `ssis\KentFoods_ETL_SSIS\` — paquetes `01_ETL_KentFoods_OLTP_Stage.dtsx` y `02_ETL_KentFoods_Stage_DW.dtsx`.
- `ssis\KentFoods_Profiler\` — 5 paquetes de perfilamiento; XML en `Resultados\`.
- `evidencias\` — resultados del perfilamiento, de la validación y `resumen_perfilamiento.md`.
- `demo\` — guion, consultas para SSMS y scripts para simular cambios en el origen.
- `informe\` — texto para pegar en el informe y notas para el equipo.
- `respaldos\` — `KentFoods_DW_cargado.bak`, `KentFoods_STAGE.bak`.
- `herramientas\` — generadores de los paquetes (se pueden volver a ejecutar si se cambia el diseño): `generar_paquetes.ps1` + `DftBuilder.cs`, `generar_perfilamiento.py`, `resumir_perfilamiento.py`.

## Decisiones tomadas (para el equipo)
1. **Stage completo, DW incremental** (como en la clase S08 del profesor). Dimensiones tipo 1 (actualizar + insertar); hechos con marca de agua `MAX(id_orden)`; actualización de envíos pendientes.
2. **Corrección del modelo:** `Dim_Cliente.ClienteID` pasa a clave sustituta (IDENTITY) y se agrega `ClienteCodigo` (clave real alfanumérica del origen, única). Antes era `int` y no se podía cargar.
3. **Territorio:** un territorio por empleado (menor `TerritorioID`), declarado como limitación; la región es confiable. No se implementó la tabla puente.
4. **Transformaciones en SQL del OLE DB Source** (patrón del profesor), sin Lookup/Derived Column/Data Conversion.
5. **Dim_Tiempo** generada: calendario 2016-2018 (1.096 días), `FechaKey` = AAAAMMDD.
6. Valores de dinero con `decimal(18,2)`; `Descuento` redondeado a 2 decimales (venía como `real`).

## Pendiente / a confirmar con el equipo
- Confirmar que la retroalimentación del Avance 1 citada en el borrador (KPI 1 despacho vs entrega; preguntas de negocio omitidas) es la real y no hay más.
- Tomar las 9 capturas, pegar el texto en el Doc, y completar la Historia de cambios.
- Armar las diapositivas y ensayar la demo (cronometrar 10 min).
- Que alguien del equipo abra la solución en Visual Studio 2019 y ejecute cada paquete con F5 antes del miércoles (idealmente como administrador, para evitar el aviso de contadores de rendimiento).
- El respaldo y los scripts asumen SQL Server local por defecto (`Data Source=.`). Si otro integrante usa otra instancia, hay que cambiar las conexiones.
