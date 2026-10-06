# Resumen del perfilamiento (Data Profiling Task - KentFoods)

Fuente: `avance2/ssis/KentFoods_Profiler/Resultados/*_Profile.xml` (se abren con Data Profile Viewer).

## Resumen por tabla

| Tabla | Filas | Columnas | Columnas con nulos | Nulos totales | Claves candidatas (100 %) |
|---|---|---|---|---|---|
| Categorias | 8 | 4 | - | 0 | Categoria; CategoriaID |
| Clientes | 91 | 9 | CodigoPostal | 1 | ClienteID; CodigoPostal; Contacto; Direccion; Empresa; Telefono |
| DetalleOrden | 2155 | 5 | - | 0 | - |
| Empleados | 9 | 9 | - | 0 | Apellido; Direccion; EmpleadoID; FechaNacimiento; Nombre |
| Ordenes | 830 | 9 | FechaEnvio, CodigoPostal | 40 | OrdenID |
| Productos | 77 | 6 | - | 0 | Producto; ProductoID |
| Proveedores | 29 | 8 | - | 0 | Ciudad; Contacto; Direccion; Proveedor; ProveedorID; Telefono |
| Regiones | 4 | 2 | - | 0 | Region; RegionID |
| TerritoriosEmpleados | 49 | 2 | - | 0 | TerritorioID |
| Territorios | 53 | 3 | - | 0 | Territorio; TerritorioID |
| Transportistas | 3 | 3 | - | 0 | Telefono; Transportista; TransportistaID |

## Detalle por columna

### Categorias (8 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| CategoriaID | Int | 0 | 8 |  | 1 | 8 |
| Categoria | NVarChar | 0 | 8 | 7-14 |  |  |
| Descripcion | NText | 0 |  |  |  |  |
| Imagen | Image | 0 |  |  |  |  |

### Clientes (91 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| ClienteID | NChar | 0 | 91 | 5-5 |  |  |
| Empresa | NVarChar | 0 | 91 | 8-36 |  |  |
| Contacto | NVarChar | 0 | 91 | 8-23 |  |  |
| Cargo | NVarChar | 0 | 12 | 5-30 |  |  |
| Direccion | NVarChar | 0 | 91 | 11-46 |  |  |
| Ciudad | NVarChar | 0 | 69 | 4-15 |  |  |
| CodigoPostal | NVarChar | 1 | 86 | 4-9 |  |  |
| Pais | NVarChar | 0 | 21 | 2-11 |  |  |
| Telefono | NVarChar | 0 | 91 | 8-17 |  |  |

### DetalleOrden (2155 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| OrdenID | Int | 0 | 830 |  | 10248 | 11077 |
| ProductoID | Int | 0 | 77 |  | 1 | 77 |
| PrecioUnitario | Money | 0 |  |  | 2.0000 | 263.5000 |
| Cantidad | SmallInt | 0 | 55 |  | 1 | 130 |
| Descuento | Real | 0 |  |  | 0 | 0.25 |

### Empleados (9 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| EmpleadoID | Int | 0 | 9 |  | 1 | 9 |
| Apellido | NVarChar | 0 | 9 | 4-9 |  |  |
| Nombre | NVarChar | 0 | 9 | 4-8 |  |  |
| Cargo | NVarChar | 0 | 4 | 13-24 |  |  |
| FechaNacimiento | DateTime | 0 | 9 |  | 1937-09-19T00:00:00.00 | 1966-01-27T00:00:00.00 |
| FechaContratacion | DateTime | 0 | 8 |  | 1992-04-01T00:00:00.00 | 1994-11-15T00:00:00.00 |
| Direccion | NVarChar | 0 | 9 | 15-30 |  |  |
| Ciudad | NVarChar | 0 | 5 | 6-8 |  |  |
| Pais | NVarChar | 0 | 2 | 2-3 |  |  |

### Ordenes (830 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| OrdenID | Int | 0 | 830 |  | 10248 | 11077 |
| ClienteID | NChar | 0 | 89 | 5-5 |  |  |
| EmpleadoID | Int | 0 | 9 |  | 1 | 9 |
| FechaOrden | DateTime | 0 | 480 |  | 2016-07-04T00:00:00.00 | 2018-05-06T00:00:00.00 |
| FechaEnvio | DateTime | 21 | 387 |  | 2016-07-10T00:00:00.00 | 2018-05-06T00:00:00.00 |
| EnviadoPor | Int | 0 | 3 |  | 1 | 3 |
| CiudadEnvio | NVarChar | 0 | 70 | 4-15 |  |  |
| PaisEnvio | NVarChar | 0 | 21 | 2-11 |  |  |
| CodigoPostal | NVarChar | 19 | 84 | 4-9 |  |  |

### Productos (77 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| ProductoID | Int | 0 | 77 |  | 1 | 77 |
| Producto | NVarChar | 0 | 77 | 4-32 |  |  |
| ProveedorID | Int | 0 | 29 |  | 1 | 29 |
| CategoriaID | Int | 0 | 8 |  | 1 | 8 |
| CantidadPorUnidad | NVarChar | 0 | 70 | 5-20 |  |  |
| PrecioUnitario | Money | 0 |  |  | 2.5000 | 263.5000 |

### Proveedores (29 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| ProveedorID | Int | 0 | 29 |  | 1 | 29 |
| Proveedor | NVarChar | 0 | 29 | 8-38 |  |  |
| Contacto | NVarChar | 0 | 29 | 10-26 |  |  |
| Cargo | NVarChar | 0 | 15 | 5-28 |  |  |
| Direccion | NVarChar | 0 | 29 | 12-45 |  |  |
| Ciudad | NVarChar | 0 | 29 | 4-13 |  |  |
| Pais | NVarChar | 0 | 16 | 2-11 |  |  |
| Telefono | NVarChar | 0 | 29 | 8-15 |  |  |

### Regiones (4 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| RegionID | Int | 0 | 4 |  | 1 | 4 |
| Region | NChar | 0 | 4 | 7-8 |  |  |

### TerritoriosEmpleados (49 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| EmpleadoID | Int | 0 | 9 |  | 1 | 9 |
| TerritorioID | NVarChar | 0 | 49 | 5-5 |  |  |

### Territorios (53 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| TerritorioID | NVarChar | 0 | 53 | 5-5 |  |  |
| Territorio | NChar | 0 | 52 | 4-16 |  |  |
| RegionID | Int | 0 | 4 |  | 1 | 4 |

### Transportistas (3 filas)

| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |
|---|---|---|---|---|---|---|
| TransportistaID | Int | 0 | 3 |  | 1 | 3 |
| Transportista | NVarChar | 0 | 3 | 14-16 |  |  |
| Telefono | NVarChar | 0 | 3 | 14-14 |  |  |
