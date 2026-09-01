# INF330 — Proyecto BI Kent Foods (Grupo 7)

## Aviso importante sobre esta nota
El informe "real" se está redactando en un **doc en el navegador (Google Docs u
similar), no en este repositorio**. Los archivos locales (`grupo7_desarrolloPlantilla.pdf`,
`INF330_Plantilla Informe 1 BI.docx`) son exports/snapshots y **se van a desfasar**
respecto al doc del navegador — eso es esperado, no un error. Este CLAUDE.md es
un tracker de apoyo para que Claude tenga contexto entre sesiones, no la fuente
de verdad del informe.

## Contexto del proyecto
- Curso: INF330 – Bases Tecnológicas para la Inteligencia de Negocios (UTFSM).
- Caso: Kent Foods (Caso Semestral Forma C) — empresa de venta de alimentos por envíos.
- Entrega actual: Avance 1 — Modelo Dimensional.
- Proceso de negocio elegido: **Gestión de Ventas y Envíos** (desde que se emite
  la orden hasta la entrega del producto).
- Motor de datos: SQL Server, base de datos `KentFoods` (restaurada desde
  `caso_c_kentfoods/KentFoods.bak`). Esquema estilo Northwind: `Ordenes`,
  `DetalleOrden`, `Clientes`, `Empleados`, `Territorios`, `TerritoriosEmpleados`,
  `Regiones`, `Productos`, `Categorias`, `Proveedores`, `Transportistas`.
- `KentFoods_DW.bak` (raíz del repo, no versionado en `.git` como el anterior):
  backup del **modelo dimensional físico** (DW), generado por el equipo desde
  SQL Server. Verificado el 31-08-2026 restaurándolo en una BD temporal: 6
  dimensiones (`Dim_Tiempo`, `Dim_Producto`, `Dim_Cliente`, `Dim_Transportista`,
  `Dim_Empleado`, `Dim_Proveedor`) + `Fact_Ventas` con las 7 FK correctas y
  nullability tal como se describe en 3.4/3.5 del informe. Todas las tablas
  están **vacías** (0 filas) — es solo el esquema, el ETL/carga de datos es el
  siguiente hito del proyecto (no de este avance).
- **Rúbrica real de evaluación:** `Rubrica_Avance1_Modelo_Dimensional.xlsx`
  (raíz del repo). 8 criterios ponderados (100 pts totales, aprobación 55).
  Los "Objetivos específicos" del informe (página 4) solo mapean 1:1 a 5 de
  los 8 criterios (los que corresponden a 3.1-3.5) — los criterios 3
  ("Análisis de utilidad y calidad de los datos fuente", 10 pts) y 8
  ("Calidad del informe, conclusiones y referencias", 5 pts) no tienen un
  objetivo/sección dedicada en el informe. Usar el texto literal de esta
  rúbrica (no los objetivos de la página 4) como fuente de verdad al evaluar
  si algo está "al 100%".
- Nota de esquema clave: la región **no** cuelga directamente de `Ordenes` ni de
  `Clientes`. Se llega a región vía el empleado que tomó la orden:
  `Ordenes.EmpleadoID → TerritoriosEmpleados → Territorios → Regiones`.

## ⚠️ Hallazgo clave: la jerarquía Territorio no es confiable (verificado 31-08-2026)

**Resumen del problema:** el modelo declara la jerarquía geográfica
`País > Región > Territorio > Ciudad` (sección 3.2 del informe, y repetida en
la slide 6 y 7 de la presentación) como si los 4 niveles fueran igual de
confiables para analizar ventas. **No lo son.** Solo `País > Región` es
confiable. `Territorio` (y por lo tanto cualquier análisis de ventas a nivel
de Territorio) **no es recuperable** con el modelo tal como está diseñado.

**Por qué pasa — mecanismo exacto:**
- La única manera de llegar a información geográfica de una venta es vía el
  empleado que tomó la orden: `Ordenes.EmpleadoID → TerritoriosEmpleados →
  Territorios → Regiones`. Ninguna orden tiene un campo propio de
  territorio/región — la geografía de la venta es 100% heredada del empleado.
- `TerritoriosEmpleados` es una tabla puente **muchos-a-muchos real**: un
  empleado cubre varios territorios. Verificado contra `KentFoods` con query
  directa: de 9 empleados, **7 cubren 3 o más territorios** (rango completo:
  EmpleadoID 7→10 territorios, 9→7, 2→7, 5→7, 6→5, 3→4, 8→4, 4→3, 1→2). Cero
  empleados con un solo territorio.
- Lo que sí se verificó y es sólido: **los territorios de un mismo empleado
  siempre caen dentro de UNA sola región** (0 empleados con territorios en
  más de 1 región). Por eso el bug de Q2 (duplicación de ventas al unir por
  `TerritoriosEmpleados` sin `DISTINCT`) se pudo arreglar simplemente
  deduplicando `EmpleadoID + RegionID` — a nivel Región, el dato es único y
  el fix es 100% válido (la suma de las 4 regiones cuadra exacto con la venta
  total de la empresa, $1.265.793 — verificado ejecutando la query real).
- El problema es un nivel más abajo: `Dim_Empleado` tiene un solo campo
  `Territorio` (no una lista), porque el grano de la dimensión es una fila
  por `EmpleadoID`. Para poblar ese campo en el ETL hay que elegir **un**
  territorio de los 2 a 10 que ese empleado realmente cubre — cualquier
  criterio de selección (el primero, el de menor ID, etc.) es **arbitrario**
  y no refleja en qué territorio específico ocurrió cada venta individual.

**Por qué es exactamente el mismo tipo de bug que ya encontraron en Q2, pero
sin corregir:** Q2 era "duplicar ventas por región al no deduplicar el join
muchos-a-muchos". Este es "perder/inventar el territorio por forzar un
muchos-a-muchos dentro de un atributo de una sola fila". Ambos nacen de la
misma causa raíz (`TerritoriosEmpleados` es muchos-a-muchos), pero uno se
detectó y arregló (Región) y el otro quedó sin detectar (Territorio) porque
no rompe ningún KPI de los 5 definidos — ninguno pide analizar por Territorio
específicamente, así que nunca se topó con el problema al validar KPI2.

**Consecuencia concreta:** si alguien (el profesor, en la Q&A) pregunta "¿y
si quiero ver ventas por Territorio, no por Región?", la respuesta honesta es
que **no se puede** con los datos disponibles — el dato transaccional
simplemente no existe a ese nivel de detalle. Esto no es un error de
implementación que se arregle tocando el DDL; es un límite real de la fuente
de datos (el mismo tipo de limitación que debería salir a relucir en el
análisis de calidad/utilidad de datos — ver Criterio 3 en la sección de
pendientes).

**Decisión del equipo (01-09-2026): divulgar, no corregir en este avance.**
Se evaluó la opción de "parchar" con una frase discreta en el informe, pero
el equipo decidió algo más fuerte y más honesto: **reconocer el límite
explícitamente, en voz alta, y dejar la corrección para el próximo avance**
— no esconderlo ni tampoco sobre-ingenierizarlo ahora. Razones a favor de
esta jugada (validado, no es solo una corazonada):
- No rompe ninguno de los 5 KPI actuales — nadie pide análisis a nivel
  Territorio, así que no es un error "fatal" para esta entrega.
- Encaja perfecto con el Criterio 3 de la rúbrica ("Análisis de utilidad y
  **calidad de los datos** fuente", 10 pts) — declarar una limitación real y
  entendida es exactamente el tipo de hallazgo que ese criterio premia,
  igual que el bug de Q2 y las 21 órdenes sin fecha.
- Es más seguro que el status quo: si el profesor lo detecta solo (revisando
  la jerarquía contra los datos, como hice yo), parece que el equipo no
  entendió su propio modelo. Si el equipo lo señala primero, parece
  dominio y madurez analítica.
- Arreglarlo de verdad (bridge table Kimball) es over-engineering para lo
  que piden los 5 KPI de este avance — mejor dejarlo para cuando realmente
  se necesite ese nivel de detalle.

**Cómo se implementa esta decisión (no es solo una frase suelta):**
1. Informe, 3.2/3.3: declarar explícitamente que la jerarquía geográfica es
   confiable hasta Región para fines de venta; Territorio queda documentado
   como limitación conocida de la fuente de datos (no un descuido).
2. Informe: si se agrega el subapartado de Criterio 3 (calidad de datos,
   ver sección de pendientes), este hallazgo va ahí como tercer ejemplo
   concreto, junto al bug de Q2 y las 21 órdenes sin fecha.
3. Presentación (`PPT_Maestro_Brief_Avance1.md`, slide 6): mismo hallazgo,
   presentado como limitación conocida y ya resuelta en cuanto a diagnóstico
   — con nota explícita de que la implementación del fix (bridge table)
   queda para Avance 2.
4. **Exposición oral: mencionarlo en voz alta, no solo dejarlo escrito en
   letra chica.** Es la parte que más vende la jugada — decirlo activa
   ("detectamos esta limitación, aquí está la evidencia, la resolvemos en
   el próximo avance") en vez de esperar a que salga en la Q&A.
5. Fix técnico real (bridge table Kimball entre hechos y territorio con
   factor de ponderación) — explícitamente diferido a Avance 2, no a este.

## Preguntas de negocio y KPIs — versión final revisada (validada contra la BD)
Cada pregunta/KPI fue revisada una por una: se corrigió texto copiado de otro
KPI (Requisito/Descripción que no correspondía), se agregó la dimensión de
segmentación que faltaba en la fórmula (transportista/región/cliente/categoría),
y se corrió la query real contra `KentFoods` para confirmar que los datos
existen y el join no da nulos. Cobertura de tipos exigida (mínimo 1 ratio, 1
variación, 1 promedio) → **cumplida**: promedio = KPI1 y KPI4, variación = KPI2,
ratio = KPI5.

1. ¿Qué transportistas cumplen los plazos y cómo varía el tiempo promedio de
   envío por transportista? → **KPI 1 — Tiempo promedio de envío** (promedio).
   `KPI(tr,t) = Σ(FechaEnvio−FechaOrden) del transportista tr en periodo t / Cantidad de Órdenes del transportista tr en periodo t`.
2. ¿Qué región(es) genera(n) más ingreso por venta y cuál es su variación
   respecto al período anterior? → **KPI 2 — Variación de ventas por región** (variación).
   `KPI(r,t) = (Ventas tot. región r, periodo t − Ventas tot. región r, periodo t−1) / Ventas tot. región r, periodo t−1 × 100`.
3. ¿Qué proveedores generan más ingreso (precio unitario y descuentos)? →
   **KPI 3 — Ventas totales por proveedor** (agregado, sin tipo obligatorio).
   `KPI(p,t) = Σ(PrecioUnitario_i × Cantidad_i × (1−Descuento_i))` para las líneas
   de `DetalleOrden` del proveedor p en el periodo t.
4. ¿Cómo es el comportamiento de compra del cliente en volumen/cantidad por
   orden? → **KPI 4 — Promedio de compras por pedido, por cliente** (promedio).
   `KPI(c,t) = Σ Cantidad_i (DetalleOrden del cliente c, periodo t) / Total de Órdenes del cliente c en periodo t`.
5. ¿Qué % de la venta total corresponde a cada categoría de producto? →
   **KPI 5 — % de venta por categoría de producto** (ratio). **Reemplaza** al
   "Índice de productos activos" original de la plantilla (ese medía % del
   catálogo que tuvo ventas, algo totalmente distinto — no calzaba con la
   pregunta).
   `KPI(cat,t) = Venta total categoría cat, periodo t / Venta total empresa, periodo t × 100`.

## Estado de avance
El informe real vive en un doc del navegador; el archivo local que se exporta
de ahí para revisión es `grupo7_desarrollo.pdf` (ojo: reemplazó al viejo
`grupo7_desarrolloPlantilla.pdf`, que ya no existe). Cada vez que el usuario
dice "revisa"/"mira" sin adjuntar nada, lo más probable es que haya un nuevo
export de ese PDF — chequear el timestamp del archivo antes de asumir que no
cambió nada.

### ✅ 3.1 Proceso de negocio, preguntas y KPIs — completo y validado
Las 5 preguntas se simplificaron/afinaron y los 5 KPIs quedaron numerados
secuencialmente (KPI1→Q1, ..., KPI5→Q5), cada uno con Requisito/Categoría/
Descripción/fórmula coherentes, y un párrafo corto de validación de datos
debajo de cada tablita (sin revelar el resultado final del KPI — el usuario
prefiere no "spoilear" las respuestas antes de la sección de resultados).
- **Q1** tiempo de envío, parametrizado por transportista.
- **Q2** variación de ventas por región. **Bug real encontrado y corregido:**
  unir directo `Ordenes→Empleados→TerritoriosEmpleados→Territorios→Regiones`
  duplica las ventas (~5x), porque un empleado puede tener varios territorios
  dentro de la misma región (2 a 10 territorios por empleado). Fix: usar
  `SELECT DISTINCT EmpleadoID, RegionID` desde TerritoriosEmpleados/Territorios
  antes de unir con Ordenes. Con el fix, la suma por región cuadra exacto con
  la venta total de la empresa ($1.265.793).
- **Q3** ventas por proveedor — 29 proveedores, sin nulos.
- **Q4** compras por cliente, parametrizado por cliente.
- **Q5** % venta por categoría — reemplazó al "Índice de productos activos"
  original (medía otra cosa, no calzaba con la pregunta).

### ✅ 3.2 Granularidad y Jerarquías — completo, revisado y correcto
Grano: una fila = una línea de producto dentro de una orden específica.
Jerarquías: Tiempo (Año>Trimestre>Mes>Día), Geográfica (País>Región>Territorio>
Ciudad), Producto (Categoría>Producto).

### ✅ 3.3 Dimensiones del modelo — completo, 6 dimensiones
Se agregaron 3 dimensiones nuevas a las 3 originales de la plantilla
(Dim_Tiempo, Dim_Producto, Dim_Cliente), porque sin ellas 3 de los 5 KPIs no
tenían con qué calcularse:
- Dim_Transportista (TransportistaID, Transportista) — para KPI1.
- Dim_Empleado (EmpleadoID, NombreEmpleado, Territorio, Región) — para KPI2.
  Se usa Empleado (no una dimensión de Territorio suelta) porque la región
  cuelga del empleado que tomó la orden, y así se evita en el modelo el mismo
  problema de duplicación que se encontró y corrigió en el análisis de Q2.
- Dim_Proveedor (ProveedorID, Proveedor, Ciudad, País) — para KPI3.

**⚠️ Ver hallazgo clave sobre `Dim_Empleado.Territorio` en la sección
dedicada más abajo ("Hallazgo clave: la jerarquía Territorio no es confiable")
— afecta 3.2 y 3.3, y también las slides de la presentación.**

### ✅ 3.4 Medidas del modelo — completo (Fact_Ventas, no Hechos_Ventas)
Ojo: el nombre final en el doc/DDL es `Fact_Ventas` (no `Hechos_Ventas` como se
barajó antes). Grano = línea de producto por orden. FKs a las 6 dimensiones,
más `id_orden`/`id_producto` como PK compuesta.
- Medidas finales: `cantidad`, `precio_unitario`, `descuento`, `monto_neto`
  (= precio_unitario × cantidad × (1−descuento)), `dias_envio` (=
  DATEDIFF(día, FechaOrden, FechaEnvio), calculado en el ETL).
- **DiasEnvio sigue siendo semi-aditivo** (es de cabecera de orden, se repite
  por línea) — el doc ya documenta explícitamente que no debe sumarse entre
  líneas, sino agruparse por `id_orden` y luego promediar por transportista
  para KPI1. Bien resuelto y explicado en el texto.

### ✅ 3.5 Modelo Dimensional físico en SQL Server — completo y **verificado real**
Ya no es solo una captura de pantalla: el 31-08-2026 se restauró
`KentFoods_DW.bak` en una BD de verificación temporal (`KentFoods_DW_check`,
ya eliminada) y se confirmó que el esquema real coincide 100% con el DDL y el
diagrama del doc — 6 dimensiones + `Fact_Ventas`, las 7 FK apuntando a las
columnas correctas, nullability correcta (`id_transportista`, `id_fecha_envio`,
`dias_envio` nullable; el resto NOT NULL). Todas las tablas están vacías (0
filas) — normal, el ETL/carga es el siguiente hito del proyecto, no de este
avance (confirmado también en `caso_c_kentfoods/Caso_Semestral_FormaC.pdf`:
el proyecto semestral completo incluye ETL vía SSIS + cubos OLAP + Dashboard
en Power BI como entregas posteriores; Avance 1 solo pide el modelo
dimensional con DDL + diagrama, que es exactamente lo que hay).

### ✅ Conclusiones y Bibliografía — completo
Conclusiones reflexiona sobre metodología Kimball, calidad de datos como
mayor desafío, y próximos pasos (ETL). Bibliografía con 4 referencias en
formato consistente.

## Pendiente para llegar al 100% real de la rúbrica
Verificado contra el texto literal de `Rubrica_Avance1_Modelo_Dimensional.xlsx`
(8 criterios, 100 pts) + las instrucciones generales de
`caso_c_kentfoods/Caso_Semestral_FormaC.pdf` (formato del informe) + comparación
con `INF330_Plantilla Informe 1 BI.docx` (para saber qué es "culpa del grupo"
vs. limitación de la plantilla oficial). Estado al 31-08-2026:

- **[Alto impacto, 10 pts] Criterio 3 "Análisis de utilidad y calidad de los
  datos fuente" no tiene sección propia.** Ni el informe ni la plantilla
  oficial tienen un apartado dedicado a esto — el único rastro son las notas
  de validación sueltas (resaltadas en amarillo) debajo de cada KPI en 3.1,
  que están acotadas a lo mínimo que necesita ese KPI puntual (no cubren
  claves/tipos de datos/duplicados a nivel general del esquema fuente). Fix
  sugerido: agregar un subapartado corto al final de 3.1 (antes de pasar a
  3.2 Granularidad) que generalice lo ya investigado — tablas y claves
  usadas, tipos de datos, duplicados/inconsistencias a nivel de esquema, no
  solo por KPI. No requiere renumerar nada.
- **[Criterio 8 / instrucción general "e"] Redacción en primera persona
  plural en 3 lugares** — viola "redactado en tercera persona" (regla
  explícita del caso, página 1): pág. 9 "Podemos analizar **nuestro**
  inventario (KPI 5)"; pág. 17 "nos permitió comprender...", "...**nos**
  corresponde avanzar hacia la fase de Adquisición de Datos". Fix trivial de
  redacción.
- **[Instrucción general "h"] Faltan "Sección" y "Nombre del profesor(a)"**
  en todo el documento — la plantilla oficial tampoco trae campos para esto,
  pero es fácil agregarlos como filas extra en la tabla "1. Identificación
  del Proyecto" (pág. 2), junto a N° grupo / Nombre Proyecto.
- 2 typos que llevan varias revisiones sin corregirse: inconsistencia
  "**Ventas** tot." (numerador) / "**Venta** tot." (denominador) en la
  fórmula del KPI2 (pág. 6). *(El doble punto del Requisito del KPI5 sí se
  corrigió.)*
- Resaltado amarillo residual en las notas de validación de cada KPI (pág.
  6-8) — cosmético, sigue sin limpiarse pese a estar anotado hace rato.
- Campo "Nombre Proyecto" (pág. 2, tabla "Identificación del Proyecto") dice
  literalmente **"7"** (copiado de "N° grupo") — probablemente debería ser
  un nombre descriptivo del proyecto, no el número de grupo repetido.
- "Historia de cambios" (pág. 2) no registra quién agregó 3.5/Conclusiones/
  Bibliografía (se quedó en la versión 4, sin la ronda de cambios más
  reciente). Números de página del Índice (pág. 3) tampoco calzan con la
  paginación real del PDF final.
- **Descartado tras revisar la plantilla:** la ubicación del número de
  página (arriba, en la tabla de encabezado — "Página N°: X de 17" — en vez
  de "al pie, lado inferior derecho" como dice la instrucción general) **no
  es un problema real** — es así en la plantilla oficial obligatoria para
  todos los grupos, no algo que el grupo hizo mal. No tocar.
- Fuente/tamaño (Calibri 11), cantidad de páginas (17 de máx. 50), y las 6
  secciones obligatorias (Portada/Índice/Introducción/Desarrollo/
  Conclusiones/Bibliografía) — todo ✅ verificado, sin problema.

## Presentación (`Kents Food Avance 1.pdf`, 11 slides)
No existe una pauta/rúbrica específica para la presentación — solo la del
informe escrito (`Rubrica_Avance1_Modelo_Dimensional.xlsx`), que no la
menciona. El único dato de formato de exposición que aparece en
`caso_c_kentfoods/Caso_Semestral_FormaC.pdf` (10 min exposición + 5 min
preguntas) describe la presentación **final** del proyecto completo (con
ETL/OLAP/Dashboard), no necesariamente este checkpoint de Avance 1 — no
asumir que aplica sin confirmar con el profesor/syllabus.

Revisada el 01-09-2026, comparada contra el informe y la BD real:
- Estructura y profundidad (11 slides, ~1 tema por slide, calca la
  estructura del informe) están bien calibradas para una exposición corta —
  no hace falta agregar más data/detalle, el riesgo es lo contrario
  (saturar slides de texto).
- Diagrama ER (slide 9) coincide 100% con lo verificado en la BD restaurada
  real. Slide de Conclusiones (10) menciona correctamente los 2 hallazgos
  reales de calidad de datos (órdenes sin fecha, duplicación geográfica).
- **Error de contenido real: slide 7 dice "Dim_Proveedor: Rentabilidad
  asociada a los proveedores".** Es incorrecto — el modelo no puede medir
  rentabilidad/margen porque `Productos` no tiene columna de costo, solo
  `PrecioUnitario` (precio de venta). Lo que sí mide KPI3 y el modelo es
  **ventas/ingresos** por proveedor, no rentabilidad. Cambiar la palabra.
- **Slide 5 (KPIs): la imagen del dashboard mockup muestra categorías
  fabricadas que no son de Kent Foods** ("Electrónica 42%, Moda 28%, Hogar
  18%, Otros 12%") — claramente una imagen de stock/IA genérica, no un
  output real. Las 8 categorías reales (verificadas en BD) son todas de
  alimentos: Beverages, Condiments, Confections, Dairy Products,
  Grains/Cereals, Meat/Poultry, Produce, Seafood. Cambiar la imagen o al
  menos evitar que se lean números/categorías incoherentes con el rubro.
- Slides 6 y 7 repiten la jerarquía "País>Región>Territorio>Ciudad" y
  "Dim_Empleado: ventas por región/**territorio**" — aplica el mismo
  hallazgo de Territorio/Región documentado arriba; ajustar ahí también si
  se corrige en el informe.
- Slide 7 usa "Dim_Producto: análisis de **inventario** y categorías" —
  mismo uso impreciso de "inventario" que la página 9 del informe (el
  modelo analiza ventas por categoría, no niveles de stock).
- Sin errores en: fecha de la portada (miércoles 2 de septiembre de 2026 es
  correcto, se verificó el día de la semana), nombres del equipo, tabla de
  hechos/medidas (slide 8, coincide exacto con el informe y el DDL).

## Convenciones de trabajo
- El desarrollo de las queries/análisis ocurre contra la BD `KentFoods` directamente
  (no hay carpeta `*.sql` en el repo local todavía).
- El usuario redacta el informe final en el doc del navegador; a Claude le toca
  ayudar con el análisis/queries y mantener este tracker al día a grandes rasgos.
- Archivos de instrucciones/formato a revisar cuando se pregunte por
  cumplimiento/100%: `Rubrica_Avance1_Modelo_Dimensional.xlsx` (rúbrica real,
  8 criterios), `caso_c_kentfoods/Caso_Semestral_FormaC.pdf` (caso + reglas
  generales de formato del informe, página 1), `instrucciones_buzon_entrega.txt`
  (extracto de los requisitos específicos del modelo dimensional), y
  `INF330_Plantilla Informe 1 BI.docx` (plantilla oficial — sirve para
  distinguir qué es limitación de la plantilla vs. error real del grupo).
- `Kents Food Avance 1.pdf` es la presentación/slides del avance (distinta
  del informe `grupo7_desarrollo.pdf`) — también se desfasa con el tiempo,
  revisar timestamp igual que con el PDF del informe.
