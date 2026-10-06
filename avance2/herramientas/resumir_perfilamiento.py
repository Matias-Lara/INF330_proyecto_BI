# Consolida los XML de Data Profiling (Resultados\*.xml) en un resumen por tabla: filas, nulos, claves candidatas, rango de valores.
# Uso:  python resumir_perfilamiento.py  ->  avance2/evidencias/resumen_perfilamiento.md
import os, glob, xml.etree.ElementTree as ET

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
RES = os.path.join(REPO, 'avance2', 'ssis', 'KentFoods_Profiler', 'Resultados')
OUT = os.path.join(REPO, 'avance2', 'evidencias', 'resumen_perfilamiento.md')
NS = {'d': 'http://schemas.microsoft.com/sqlserver/2008/DataDebugger/'}

def q(tag):
    return '{%s}%s' % (NS['d'], tag)

filas = []
claves = {}
for path in sorted(glob.glob(os.path.join(RES, '*_Profile.xml'))):
    root = ET.parse(path).getroot()
    out = root.find('d:DataProfileOutput/d:Profiles', NS)
    tabla, rows = None, 0
    cols = {}
    for p in out:
        t = p.find('d:Table', NS)
        if t is not None:
            tabla = t.get('Table')
            rc = int(t.get('RowCount', '-1'))
            rows = max(rows, rc)
        kind = p.tag.split('}')[1]
        if kind == 'ColumnNullRatioProfile':
            c = p.find('d:Column', NS).get('Name')
            cols.setdefault(c, {})['nulos'] = int(p.find('d:NullCount', NS).text)
            cols[c]['tipo'] = p.find('d:Column', NS).get('SqlDbType')
        elif kind == 'ColumnStatisticsProfile':
            c = p.find('d:Column', NS).get('Name')
            cols.setdefault(c, {})['min'] = (p.find('d:MinValue', NS).text or '') if p.find('d:MinValue', NS) is not None else ''
            cols[c]['max'] = (p.find('d:MaxValue', NS).text or '') if p.find('d:MaxValue', NS) is not None else ''
        elif kind == 'ColumnValueDistributionProfile':
            c = p.find('d:Column', NS).get('Name')
            cols.setdefault(c, {})['distintos'] = int(p.find('d:NumberOfDistinctValues', NS).text)
        elif kind == 'ColumnLengthDistributionProfile':
            c = p.find('d:Column', NS).get('Name')
            cols.setdefault(c, {})['len'] = '%s-%s' % (p.find('d:MinLength', NS).text, p.find('d:MaxLength', NS).text)
        elif kind == 'CandidateKeyProfile':
            kc = [x.get('Name') for x in p.findall('d:KeyColumns/d:Column', NS)]
            claves.setdefault(tabla, []).append(' + '.join(kc))
    filas.append((tabla, rows, cols))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as fh:
    fh.write('# Resumen del perfilamiento (Data Profiling Task - KentFoods)\n\n')
    fh.write('Fuente: `avance2/ssis/KentFoods_Profiler/Resultados/*_Profile.xml` (se abren con Data Profile Viewer).\n\n')
    fh.write('## Resumen por tabla\n\n| Tabla | Filas | Columnas | Columnas con nulos | Nulos totales | Claves candidatas (100 %) |\n|---|---|---|---|---|---|\n')
    for tabla, rows, cols in filas:
        con_nulos = [c for c, v in cols.items() if v.get('nulos', 0) > 0]
        tot = sum(v.get('nulos', 0) for v in cols.values())
        fh.write('| %s | %s | %d | %s | %d | %s |\n' % (tabla, rows, len(cols), ', '.join(con_nulos) or '-', tot,
                                                       '; '.join(sorted(set(claves.get(tabla, [])))) or '-'))
    fh.write('\n## Detalle por columna\n')
    for tabla, rows, cols in filas:
        fh.write('\n### %s (%s filas)\n\n| Columna | Tipo | Nulos | Distintos | Longitud | Min | Max |\n|---|---|---|---|---|---|---|\n' % (tabla, rows))
        for c, v in cols.items():
            fh.write('| %s | %s | %s | %s | %s | %s | %s |\n' % (c, v.get('tipo', ''), v.get('nulos', ''), v.get('distintos', ''),
                                                              v.get('len', ''), (v.get('min', '') or '')[:22], (v.get('max', '') or '')[:22]))
print('Escrito', OUT)
