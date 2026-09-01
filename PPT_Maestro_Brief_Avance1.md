# Brief Maestro — Presentación Avance 1 · Kent Foods (Modelo Dimensional)

## Cómo usar este documento
Este archivo es **autosuficiente**: una sesión nueva de Claude debería poder
construir el PPT completo solo con esto. Si quiere más profundidad o quiere
citar algo textual, puede además leer (todos en este mismo directorio):
- `grupo7_desarrollo.pdf` — informe completo (fuente de fórmulas de KPI y texto).
- `CLAUDE.md` — tracker del proyecto con contexto e historial de hallazgos
  (incluye la sección detallada del problema Territorio/Región citado abajo).
- `Kents Food Avance 1.pdf` — la presentación **anterior** que este brief
  reemplaza. Es solo referencia de qué NO repetir — **no copiar sus imágenes**.
- `Rubrica_Avance1_Modelo_Dimensional.xlsx` — rúbrica real (del informe
  escrito; no existe una pauta separada para la presentación, ver sección 7).

**Regla de oro para las imágenes/íconos de cada slide:**
- Si dice **`AQUÍ VA: ...`** → es una captura/foto real que el usuario debe
  pegar a mano (viene de SQL Server, del informe, etc.). Dejar un placeholder
  literal con ese texto dentro de un recuadro — no inventar un reemplazo.
- Cualquier otro visual descrito (ícono, diagrama, gráfico) **debe generarse
  de verdad** al construir el PPT — no dejarlo como texto/placeholder. Usar
  la skill `pptx` (o la que corresponda) para producirlo.

## 0. Contexto en una página
- Curso INF330 (UTFSM), caso Kent Foods (empresa de venta de alimentos por
  envío), Avance 1 = solo el Modelo Dimensional (ETL/OLAP/Dashboard son de
  avances posteriores, no van en esta presentación).
- Proceso de negocio: **Gestión de Ventas y Envíos**.
- Equipo: Matías Fernández, Renato Martínez, Iván Bustos, Matías Lara.
- No se encontró un límite de tiempo específico para *esta* presentación de
  avance (el único dato del caso — 10 min exposición + 5 min preguntas —
  describe la presentación *final* del proyecto completo). 12 slides a ritmo
  natural dan ~6-9 min, razonable; confirmar con el profesor si aplica otro
  límite.

## 1. Principios de diseño
1. **Cero imágenes de relleno.** El defecto #1 de la versión anterior: casi
   todas sus imágenes eran fotos/ilustraciones de stock genéricas sin
   relación real con el contenido (un carrito de compras, un cubo digital
   con símbolos, un embudo futurista). Si una slide no tiene un visual que
   aporte información real, va sin imagen — texto limpio y bien jerarquizado
   es preferible a decoración vacía.
2. **Minimalista pero llamativo.** Se logra con color, no con más elementos:
   íconos tipo insignia (badge circular en azul suave + glifo navy),
   números reales en grande cuando hay un dato fuerte que mostrar, harto
   espacio en blanco. No con ilustraciones fotorrealistas ni gradientes
   "sci-fi".
3. **Un solo sistema visual, consistente en las 12 slides** (ver sección 6)
   — la versión anterior mezclaba mínimo 3 estilos distintos de imagen
   (fotorrealista IA, flat-icons, stock tech-photography), lo cual se ve
   como "imágenes puestas por poner algo", no diseñado.
4. **Datos reales por sobre datos decorativos.** Donde se pueda mostrar una
   cifra verificada (sección 4) en vez de un ícono genérico, mostrar la
   cifra — es más fuerte y más honesto.

## 2. Errores de la versión anterior — NO repetir
- **Slide "Dimensiones" (Dim_Proveedor):** decía *"Rentabilidad asociada a
  los proveedores"*. Es incorrecto — `Productos` no tiene columna de costo,
  solo precio de venta, así que el modelo no puede medir rentabilidad/margen.
  Corregido abajo a **"ventas/ingresos"**.
- **Slide "KPIs":** el mockup de dashboard mostraba categorías inventadas
  ("Electrónica 42%, Moda 28%, Hogar 18%") que no son de Kent Foods (empresa
  de alimentos). Las 8 categorías reales están en la sección 4 — usarlas si
  se muestra cualquier cifra o gráfico de categorías.
- **Slide "Dimensiones" (Dim_Producto):** decía *"análisis de inventario"* —
  impreciso, el modelo analiza ventas por producto/categoría, no niveles de
  stock. Corregido a **"análisis de ventas por producto y categoría"**.
- **Slides "Granularidad" y "Dimensiones":** repetían la jerarquía
  `País > Región > Territorio > Ciudad` como si los 4 niveles fueran
  igual de confiables. **No lo son** — verificado contra la BD real: 7 de 9
  empleados cubren 3 o más territorios (hasta 10), todos dentro de una sola
  región. Solo `País > Región` es confiable para ventas; Territorio es
  informativo/de cobertura, no reconstruible a nivel de venta individual
  (mismo tipo de problema que el bug de duplicación de Q2, un nivel más
  abajo). Detalle completo en `CLAUDE.md`, sección "Hallazgo clave: la
  jerarquía Territorio no es confiable".
  **Decisión del equipo: no se corrige el modelo en este avance — se
  divulga explícitamente como limitación conocida** (en el informe, en la
  slide 6 de abajo, y **de palabra durante la exposición**), y se deja la
  corrección real (bridge table) para Avance 2. No es un error que rompa
  ningún KPI actual, y declararlo primero es más seguro que dejar que el
  profesor lo detecte solo. Este brief ya incorpora esa divulgación en las
  slides 6, 7 y 8 de abajo.
- **Consistencia visual:** mezclaba ilustraciones fotorrealistas de IA,
  íconos flat de stock y fotografía tech genérica en la misma presentación
  — de ahí la sensación de "imágenes puestas por poner algo". Ver sección 6.
- **Preguntas de negocio comprimidas:** la slide de proceso fusionaba 2 de
  las 5 preguntas originales en 1 bullet ("¿qué regiones y proveedores
  generan más ingresos?"). Este brief las mantiene las 5 completas y
  separadas (más fácil de defender en preguntas del profesor).

## 3. Aciertos de la versión anterior — MANTENER
- Estructura de 1 tema por slide, calcando el orden del informe — funciona
  bien para una exposición corta, no cambiarla de fondo.
- El diagrama ER (modelo físico) coincidía 100% con lo verificado
  directamente contra la base de datos real restaurada — mantener esa
  fidelidad al reutilizar la captura real (ver slide 10).
- La slide de Conclusiones mencionaba correctamente los 2 hallazgos reales
  de calidad de datos (órdenes sin fecha, duplicación geográfica) — este
  brief los promueve a su propia slide dedicada (slide 6) porque es
  contenido fuerte que antes estaba escondido en un bullet.
- Fondo crema/hueso + texto gris carbón: limpio y profesional, mantener tal
  cual (ver paleta en sección 6).
- Fidelidad de datos en la slide de Tabla de Hechos/Medidas (nombres de
  campos, PK compuesta) — coincidía exacto con el DDL real, mantener igual.

## 4. Datos verificados — única fuente de cifras (no inventar otras)
Verificado el 31-08-2026 ejecutando las queries reales contra la BD `KentFoods`:
- **Venta total de la empresa: $1.265.793,04** (suma de PrecioUnitario ×
  Cantidad × (1−Descuento) sobre las 830 órdenes).
- **Venta por región** (cuadra exacto con el total): Eastern $660.328,49 ·
  Northern $204.170,34 · Southern $202.812,84 · Western $198.481,36.
- Total órdenes: **830**. Sin `FechaEnvio` registrada: **21 (2,5%)**.
- Productos: **77**. Proveedores: **29** (relación 1 a 1 producto-proveedor,
  sin riesgo de doble conteo).
- Categorías reales (**8**, todas de alimentos): Beverages, Condiments,
  Confections, Dairy Products, Grains/Cereals, Meat/Poultry, Produce, Seafood.
- Empleados: **9**. Territorios: **53** (2 a 10 por empleado). Regiones: **4**.
- Transportistas: **3** — Federal Shipping, Speedy Express, United Package.
- `Descuento` se almacena como fracción **0–0,25** (no como 0–100).

## 5. Slides — contenido y visual

### Resumen rápido
| # | Slide | Visual |
|---|---|---|
| 1 | Portada | AQUÍ VA (logo UTFSM) + sin imagen decorativa |
| 2 | Índice | ícono badge simple, opcional |
| 3 | Introducción y Objetivos | ícono badge (tendencia/crecimiento) |
| 4 | Proceso de Negocio y Preguntas Clave | diagrama de flujo generado |
| 5 | Indicadores de Desempeño (KPIs) | 5 íconos badge, uno por KPI |
| 6 | Análisis de Calidad y Utilidad de Datos (**nueva**) | diagrama antes/después generado |
| 7 | Granularidad y Jerarquías | 3 árboles de jerarquía generados |
| 8 | Dimensiones del Modelo | set de 6 íconos badge consistentes |
| 9 | Tabla de Hechos y Medidas | ícono badge opcional / solo texto |
| 10 | Modelo Dimensional Físico (SQL Server) | **AQUÍ VA** (captura ER real) |
| 11 | Conclusiones y Próximos Pasos | ícono badge opcional |
| 12 | Cierre | mismo tratamiento que portada |

### Slide 1 — Portada
**Contenido:** Título "Modelo Dimensional — Caso Kent Foods: Avance 1" ·
curso "INF330 — Bases Tecnológicas para la Inteligencia de Negocios" ·
integrantes (Matías Fernández, Renato Martínez, Iván Bustos, Matías Lara) ·
fecha de exposición.
**Visual:** `AQUÍ VA: escudo/logo oficial UTFSM` (usar el archivo oficial
existente — no regenerar el escudo con IA). Sin ilustración decorativa de
stock; si se quiere un acento gráfico, una forma geométrica simple y
abstracta en azul (ver sección 6), no una escena fotorrealista.

### Slide 2 — Índice
**Contenido:** lista de las 9 slides de contenido (títulos exactos de las
slides 3 a 11, en orden) — a diferencia de la versión anterior, que tenía
bullets que no correspondían 1 a 1 con las slides reales.
**Visual:** ícono badge simple (ej. lista/checklist), opcional.

### Slide 3 — Introducción y Objetivos
**Contenido:**
- Contexto: Kent Foods, empresa de venta de alimentos por envío, en rápida expansión.
- Objetivo principal: desarrollar una propuesta de Inteligencia de Negocios
  para apoyar la toma de decisiones estratégicas de la organización.
- Hito actual (Avance 1): diseño del modelo dimensional (esquema estrella) y
  validación de la calidad de los datos fuente.
**Visual:** [GENERAR] ícono badge de "crecimiento/tendencia" (flecha o
barras ascendentes simples), estilo lineal, sin fotorrealismo.

### Slide 4 — Proceso de Negocio y Preguntas Clave
**Contenido:**
- Proceso seleccionado: Gestión de Ventas y Envíos (desde la emisión de la
  orden hasta la entrega del producto).
- Preguntas de negocio (las 5, completas):
  1. ¿Qué transportistas presentan mejor desempeño en el tiempo de envío?
  2. ¿Qué región(es) genera(n) más ingreso por venta, y cuál es su
     variación respecto al período anterior?
  3. ¿Qué proveedores generan más ingreso, considerando precio unitario y
     descuentos?
  4. ¿Cómo es el comportamiento de compra del cliente en volumen/cantidad
     por orden?
  5. ¿Qué porcentaje de la venta total corresponde a cada categoría de
     producto?
**Visual:** [GENERAR] diagrama de flujo simple de 3 pasos — "Orden emitida
→ Envío → Entrega" — cajas conectadas por flechas, estilo lineal en azul
sobre crema. Reemplaza la ilustración de bodega/almacén genérica anterior.

### Slide 5 — Indicadores de Desempeño (KPIs)
**Contenido:** los 5 KPI con su tipo explícito (deja clara la cobertura de
los 3 tipos exigidos por la pauta del curso):
- KPI 1 — Tiempo Promedio de Envío *(tipo: promedio)*
- KPI 2 — Variación de Ventas por Región *(tipo: variación)*
- KPI 3 — Ventas Totales por Proveedor *(agregado)*
- KPI 4 — Promedio de Compras por Pedido *(tipo: promedio)*
- KPI 5 — % de Venta por Categoría de Producto *(tipo: ratio)*
**Visual:** [GENERAR] 5 íconos badge pequeños, uno por KPI, mismo estilo y
paleta: reloj/camión (KPI1) · flecha sobre mapa simplificado (KPI2) ·
fábrica/caja (KPI3) · carrito/canasta (KPI4) · gráfico circular (KPI5).
**No usar categorías ni cifras inventadas** — si se agrega un mini-gráfico
de ejemplo, usar las categorías reales de la sección 4.

### Slide 6 — Análisis de Calidad y Utilidad de los Datos *(nueva)*
**Contenido:**
- Se validó sistemáticamente la base relacional fuente (tablas, claves,
  relaciones, tipos de datos) antes de diseñar el modelo.
- Hallazgo 1: 21 de 830 órdenes (2,5%) sin fecha de envío registrada →
  pedidos aún no despachados, excluidos del cálculo de KPI1.
- Hallazgo 2 (bug real, corregido): unir directo
  Empleados→TerritoriosEmpleados→Territorios inflaba las ventas por región
  (un empleado cubre entre 2 y 10 territorios). Se corrigió deduplicando
  antes de agregar — el total por región cuadra exacto con la venta total
  de la empresa: **$1.265.793**.
- Verificado sin riesgo de doble conteo: cada producto tiene un solo
  proveedor (77 productos, 29 proveedores).
- **Hallazgo 3 (limitación conocida, diagnosticada — no bloqueante):** el
  nivel Territorio de la jerarquía geográfica no es reconstruible a nivel
  de venta individual (un empleado cubre entre 2 y 10 territorios; el dato
  transaccional solo permite llegar a Región de forma confiable). No afecta
  ningún KPI de este avance. **Queda resuelto en Avance 2** con una tabla
  puente (bridge table) entre hechos y territorio.
- 🗣️ **Decir en la exposición (no solo dejarlo en la slide):** "detectamos
  esta limitación al validar los datos, la dejamos documentada, y la
  resolvemos en el próximo avance" — declararlo antes de que surja en
  preguntas del profesor.
**Visual:** [GENERAR] diagrama simple "antes → después" (dos barras: ventas
infladas por duplicación vs. valor real corregido, con un check verde en la
segunda) o un ícono badge de "lupa sobre base de datos". Mostrar el número
real ($1.265.793) en grande — es el dato más fuerte de esta slide. Para el
Hallazgo 3, un ícono badge pequeño tipo "reloj/pendiente" (no un check verde
— todavía no está resuelto, está *diagnosticado y planificado*).

### Slide 7 — Granularidad y Jerarquías
**Contenido:**
- Granularidad (nivel atómico): una línea de producto dentro de una orden
  específica.
- Jerarquías:
  - Tiempo: Año > Trimestre > Mes > Día.
  - Geografía: País > Región > ~~Territorio~~ > Ciudad *(ver nota)*.
  - Producto: Categoría > Producto.
- Nota (bullet visible, no letra chica — ya se divulgó en la slide 6):
  el nivel Territorio es informativo (cobertura del empleado), no está
  disponible a nivel de venta individual — el análisis de ventas es
  confiable hasta Región. *Limitación conocida, resuelta en Avance 2.*
**Visual:** [GENERAR] 3 diagramas de árbol/breadcrumb simples (uno por
jerarquía), estilo lineal consistente; en el de Geografía, diferenciar
visualmente el nivel Territorio (ej. atenuado o con un ícono de advertencia
pequeño) para reflejar la salvedad del texto.

### Slide 8 — Dimensiones del Modelo
**Contenido** (6 dimensiones, descripciones corregidas):
- **Dim_Tiempo:** análisis histórico por año, trimestre, mes y día.
- **Dim_Producto:** análisis de ventas por producto y categoría.
- **Dim_Cliente:** segmentación geográfica y comportamiento de compra.
- **Dim_Transportista:** comparación de desempeño logístico.
- **Dim_Empleado:** ventas por región (territorio como dato de cobertura,
  no de venta individual — limitación conocida, ver slides 6-7).
- **Dim_Proveedor:** ventas/ingresos generados por proveedor.
**Visual:** [GENERAR] set de 6 íconos badge, mismo estilo y tamaño:
calendario · producto/alimento · cliente (persona) · camión · empleado
(persona con insignia) · proveedor (fábrica/bodega). Deben verse como una
sola familia visual, no íconos sueltos de fuentes distintas.

### Slide 9 — Tabla de Hechos y Medidas
**Contenido:**
- Tabla central: `Fact_Ventas`.
- Clave primaria compuesta: `id_orden` (atributo degenerado) + `id_producto`.
- Medidas base: `cantidad`, `precio_unitario`, `descuento`.
- Medidas calculadas: `monto_neto` (ingreso real) y `dias_envio`.
- Nota: `dias_envio` es semi-aditiva (se repite por línea de una misma
  orden) — se agrupa por orden antes de promediar para KPI1.
**Visual:** [GENERAR] ícono badge simple de "mini esquema estrella"
(cuadrado central con líneas a 4-6 puntos), o dejar la slide solo con texto
— evitar decoración fotorrealista sin relación al contenido.

### Slide 10 — Modelo Dimensional Físico (SQL Server)
**Contenido:**
- Esquema estrella construido en MS SQL Server: 6 dimensiones + `Fact_Ventas`.
- Integridad referencial completa: 7 FK correctamente definidas.
- Base de datos `KentFoods_DW` creada y verificada.
**Visual:** `AQUÍ VA: captura del diagrama ER real desde SQL Server` (ya
existe uno en la página 14 de `grupo7_desarrollo.pdf` — reutilizable
directamente). Opcional: `AQUÍ VA: captura del DDL` — o, mejor, transcribir
el DDL como texto/código real dentro de la slide (no requiere captura).

### Slide 11 — Conclusiones y Próximos Pasos
**Contenido:**
- El entendimiento del negocio y sus reglas fue tan importante como la
  herramienta tecnológica.
- La validación de calidad de datos fue crítica — se detectaron y
  corrigieron anomalías reales antes de construir el modelo (ver slide 6).
- Próximos pasos (Avance 2): (1) diseño e implementación del proceso ETL
  (Extracción, Transformación y Carga); (2) resolver la limitación de
  Territorio identificada en slide 6 con una tabla puente (bridge table).
**Visual:** [GENERAR] ícono badge simple (ampolleta o checklist), opcional
— esta slide puede ir solo con texto si se prefiere más minimalismo.

### Slide 12 — Cierre
**Contenido:** "¿Preguntas?" o "Gracias" + nombres del equipo.
**Visual:** mismo tratamiento que la portada (logo placeholder + sin
decoración de stock), para cerrar con consistencia visual.

## 6. Sistema visual
- **Fondo:** crema/hueso (aprox. `#F7F3EC`) en todas las slides — igual al
  de la versión anterior, ya funciona bien, no cambiar.
- **Texto:** gris carbón oscuro (aprox. `#2B2B2B`) para cuerpo y títulos.
- **Azules de acento** (colores principales pedidos por el usuario):
  - Navy — `#1C3D5A` (glifos de íconos, títulos de énfasis, líneas).
  - Azul medio — `#2F6690` (elementos secundarios, flechas, conectores).
  - Azul claro / tinte — `#DCEAF3` (fondo circular de los íconos badge).
- **Sistema de íconos "badge":** círculo o cuadrado con esquinas
  redondeadas, relleno azul claro (`#DCEAF3`), con el glifo del ícono en
  navy (`#1C3D5A`) centrado — mismo tamaño y grosor de línea en las 12
  slides. Esto da el efecto "minimalista pero llamativo": el color bloque
  aporta impacto visual sin recurrir a fotos o ilustraciones complejas.
- **Nada de fotorrealismo ni imágenes de stock genéricas** — es la regla
  que más se rompía en la versión anterior. Todo ícono/diagrama se genera
  en este mismo estilo de línea + badge de color.
- **Cifras reales en grande** cuando aplique (slide 6 en particular) como
  recurso visual propio — un número grande en navy sobre crema es, en sí
  mismo, un elemento "llamativo" sin necesitar imagen adicional.
- Tipografía: mantener una sans-serif limpia consistente con el informe
  (Calibri o equivalente cercano).

## 7. Notas para quien construya el PPT
- Usar la skill `pptx` para generar el archivo final a partir de este brief.
- No existe una pauta/rúbrica específica para *esta* presentación — la
  única rúbrica real (`Rubrica_Avance1_Modelo_Dimensional.xlsx`) es para el
  informe escrito. Si el profesor entrega una pauta de presentación
  distinta más adelante, esa prioriza por sobre este brief.
- Todo texto de este brief es una propuesta de redacción lista para usar,
  no una obligación literal — se puede ajustar el fraseo siempre que se
  mantengan las cifras y afirmaciones técnicas exactas de la sección 4.
- Los 3 recuadros `AQUÍ VA: ...` (slides 1, 10, y opcionalmente 10-DDL) son
  las únicas imágenes que el usuario pega a mano. Todo lo demás marcado
  [GENERAR] debe quedar realmente generado en el PPT final, no como texto
  descriptivo.
