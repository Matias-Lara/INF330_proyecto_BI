# Guion de la presentación y demo en vivo — Avance 2 (Grupo 7)

**Bloque:** miércoles 7 de octubre de 2026, 11:20–11:35 · **10 min** de exposición y demo + **5 min** de preguntas.
**Rúbrica (criterio 7, 15 pts):** presentación clara y técnicamente fundamentada; ejecutar la ETL y demostrar el flujo completo y los resultados; explicar las principales transformaciones; responder las preguntas.

## Antes de entrar (checklist, 10 min antes)
- [ ] Servicios corriendo: SQL Server, Integration Services (Servicios de Windows).
- [ ] Entorno limpio: `powershell -ExecutionPolicy Bypass -File avance2\preparar_entorno.ps1 -RecrearDW` (DW y Stage vacíos; el origen no se toca).
- [ ] Visual Studio 2019 abierto **como administrador** con `avance2\ssis\KentFoods_ETL_SSIS.sln` y el paquete 01 abierto.
- [ ] SSMS abierto con `avance2\demo\03_consultas_demo.sql` y conectado a `localhost`.
- [ ] Data Profile Viewer con `ORDENES_Profile.xml` ya abierto (pestaña lista).
- [ ] Zoom del texto alto en VS y SSMS (se debe leer desde atrás).
- [ ] **Plan B** listo: ventana de PowerShell en la raíz del repo con `avance2\ejecutar_etl.ps1` (ejecuta la misma ETL por consola) y los respaldos en `avance2\respaldos\`.
- [ ] El origen está limpio (`02_revertir_cambios_origen.sql` si se usó antes).

## Guion minuto a minuto (10 min)
| Min | Qué se muestra | Qué se dice |
|---|---|---|
| 0:00–1:00 | **Diapositiva de arquitectura**: `KentFoods` → Paquete 01 → `KentFoods_STAGE` → Paquete 02 → `KentFoods_DW` | Qué problema resuelve el ETL; por qué se separa en Stage y DW (desacoplar el OLTP, depurar una sola vez, probar por etapas); herramientas: SQL Server 2019 + SSIS en Visual Studio 2019 |
| 1:00–2:30 | **Perfilamiento** (Data Profile Viewer, `ORDENES_Profile.xml`) + tabla de hallazgos | "Antes de diseñar el ETL se perfilaron las 11 tablas con el Data Profiling Task." Mostrar los 21 nulos de `FechaEnvio`. Nombrar 3 hallazgos y su regla: clave de cliente alfanumérica, descuento `real`, relleno de espacios en región/territorio. Decir en voz alta la limitación de **Territorio** |
| 2:30–3:30 | **SSMS, consulta A**: DW y Stage en 0 filas (origen: 830 órdenes, 2.155 líneas) | Estado inicial de las tres bases |
| 3:30–5:00 | **Paquete 01 en VS**: ejecutar (F5), mostrar Control Flow en verde y abrir `07_DFT_DETALLE` | "Carga completa: se vacía el Stage y se recarga." Explicar **una transformación**: `Descuento` de `real` a `decimal(5,2)` con ROUND, y `ClienteID` → `ClienteCodigo`. Luego en SSMS `EXEC SP_CONTROL_STAGE`: conteos y venta $1.265.793,04 coinciden |
| 5:00–7:15 | **Paquete 02 en VS**: ejecutar, mostrar el orden (tiempo → dimensiones → envíos pendientes → hechos → control) | Dimensiones primero, luego hechos; dimensiones = actualizar + insertar nuevos; hechos incremental. Mostrar `13_DFT_Fact_Ventas_Nuevas` con 2.155 filas y explicar `monto_neto`, `dias_envio`, `FechaKey` y la clave sustituta de cliente. Luego `EXEC SP_CONTROL_DW`: todos en OK |
| 7:15–8:30 | **Re-ejecución**: volver a ejecutar el paquete 02 | "Segunda ejecución sin cambios: 0 filas nuevas" (mostrar el contador en 0). **Opcional si hay tiempo:** ejecutar `01_simular_cambios_en_origen.sql`, correr 01 y 02 y mostrar +1 orden, +2 líneas, orden 11008 con envío y ALFKI actualizado |
| 8:30–9:30 | **KPI en SSMS** (bloques G y H de `03_consultas_demo.sql`) | KPI 1 (7,47 / 8,57 / 9,23 días) y KPI 5. Mostrar que el modelo cargado responde las preguntas de negocio. Mencionar la corrección del KPI 1 (despacho, no entrega) y la de `Dim_Cliente` |
| 9:30–10:00 | **Cierre** | 3 mensajes: (1) el perfilamiento determinó las transformaciones; (2) Stage se carga completo y el DW incremental, sin duplicar; (3) cada carga se valida con controles (conteos, venta, huérfanos). Próximos pasos: cubos OLAP y dashboard Power BI |

Después de la demo (si se hizo el paso opcional), restaurar: `02_revertir_cambios_origen.sql`.

## Estructura sugerida de diapositivas (máx. 6; la demo es lo principal)
1. Portada (Avance 2 – Proceso ETL – Grupo 7).
2. Arquitectura OLTP → Stage → DW (y los dos paquetes).
3. Perfilamiento: tabla de hallazgos → regla ETL (3 a 5 filas, las más importantes).
4. Malla ETL: Stage (paquete 01) y DW (paquete 02), con las capturas de Control Flow.
5. Validación: tabla de controles (conteos, venta, huérfanos) y la prueba incremental.
6. Conclusiones, limitaciones (Territorio, sin margen, sin entrega) y próximos pasos.

## Preguntas probables y respuestas cortas
1. **¿Por qué el Stage se carga completo y los hechos de forma incremental?** El Stage es una fotografía barata de reconstruir (830 órdenes) y así siempre refleja el origen sin arrastrar basura. Los hechos son el dato histórico del DW: recargarlos completos duplicaría o perdería historia, por eso solo se agregan las órdenes con `OrdenID` mayor al máximo cargado.
2. **¿Por qué los hechos guardan la clave sustituta del DW y no `ClienteID` del origen?** El origen usa un código alfanumérico (`ALFKI`) y puede cambiar; el DW debe estar desacoplado del OLTP. La clave sustituta es un entero compacto que además permite relacionar con la dimensión sin depender del formato del origen.
3. **¿Cuál fue la transformación más importante?** La corrección de la clave de cliente (sin ella la carga era imposible), el descuento `real` → `decimal(5,2)` (evita errores de precisión) y el cálculo de `dias_envio` con NULL para órdenes pendientes.
4. **¿Qué pasa si cambia un dato de una dimensión en el origen?** La tarea `SQL_Actualizar_Dim_*` actualiza el registro existente (dimensión tipo 1, sin historial). Se probó con el cambio de ciudad de un cliente.
5. **¿Y si una orden pendiente se despacha después?** La tarea `12_SQL_Actualizar_Envios_Pendientes` completa `id_fecha_envio`, `dias_envio` y `id_transportista`. Se probó con la orden 11008.
6. **¿Por qué no usaron Lookup o Derived Column?** Las transformaciones se resuelven en la consulta SQL del OLE DB Source, igual que en el ejemplo del curso (SQL preparado): es más legible, más fácil de validar y más rápido para este volumen.
7. **¿Por qué la venta del DW difiere en $0,25 del origen?** Cada línea se redondea a 2 decimales al guardarse en `decimal(18,2)`; la suma de 2.155 redondeos acumula $0,25 (0,00002 %). Las unidades coinciden exactamente.
8. **¿Se puede analizar ventas por territorio?** No de forma confiable: cada empleado cubre de 2 a 10 territorios y la venta no registra el territorio. Por eso `Dim_Empleado.Territorio` usa un criterio explícito y se declara como limitación. La región sí es confiable. La solución futura es una tabla puente con factor de ponderación.
9. **¿Qué pasa si `OrdenID` no es creciente?** La carga incremental se basa en ese supuesto (igual que en el sistema transaccional). Si no se cumpliera, habría que usar otra marca de agua, como la fecha de última modificación.
10. **¿Cómo se sabe que la carga está bien?** Cada paquete termina con un procedimiento de control (`SP_CONTROL_STAGE`, `SP_CONTROL_DW`) que compara conteos, unidades, venta, órdenes pendientes y registros huérfanos, deja registro en `LOG_CARGA` y hace fallar el paquete si algo no cuadra.
11. **¿Por qué el reinicio del DW usa `DELETE` y no `TRUNCATE`?** Porque las claves foráneas de `Fact_Ventas` impiden truncar las dimensiones.

## Plan B si algo falla en vivo
- **Visual Studio no abre o falla un paquete:** ejecutar `powershell -ExecutionPolicy Bypass -File avance2\ejecutar_etl.ps1` (ejecuta los dos paquetes con `dtexec` y muestra los controles) y mostrar los paquetes ya ejecutados en las capturas.
- **Un paquete falla por un estado sucio:** `avance2\preparar_entorno.ps1 -RecrearDW` y repetir (tarda ~10 s).
- **Se perdió el entorno:** restaurar `avance2\respaldos\KentFoods_DW_cargado.bak` y `KentFoods_STAGE.bak` en SSMS.
