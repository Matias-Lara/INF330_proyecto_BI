# Genera el proyecto SSIS KentFoods_Profiler (Data Profiling Task sobre las tablas de KentFoods).
# Uso:  python generar_perfilamiento.py
import os, uuid

REPO = os.path.normpath(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
PROJ = os.path.join(REPO, 'avance2', 'ssis', 'KentFoods_Profiler')
RES = os.path.join(PROJ, 'Resultados')
os.makedirs(RES, exist_ok=True)

# paquete -> lista de (tabla origen, nombre de tarea)
PAQUETES = [
    ('01_Perfil_Ordenes',        [('Ordenes', 'ORDENES'), ('DetalleOrden', 'DETALLEORDEN')]),
    ('02_Perfil_Clientes',       [('Clientes', 'CLIENTES')]),
    ('03_Perfil_Productos',      [('Productos', 'PRODUCTOS'), ('Categorias', 'CATEGORIAS'), ('Proveedores', 'PROVEEDORES')]),
    ('04_Perfil_Empleados',      [('Empleados', 'EMPLEADOS'), ('TerritoriosEmpleados', 'TERRITORIOSEMPLEADOS'),
                                  ('Territorios', 'TERRITORIOS'), ('Regiones', 'REGIONES')]),
    ('05_Perfil_Transportistas', [('Transportistas', 'TRANSPORTISTAS')]),
]

def g():
    return '{' + str(uuid.uuid4()).upper() + '}'

PROFILE = '''<?xml version="1.0" encoding="utf-16"?>
<DataProfile xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://schemas.microsoft.com/sqlserver/2008/DataDebugger/">
  <ProfileVersion>1.0</ProfileVersion>
  <DataSources />
  <DataProfileInput>
    <ProfileMode>Exact</ProfileMode>
    <Timeout>0</Timeout>
    <Requests>
      <ColumnNullRatioProfileRequest ID="NullRatioReq">
        <DataSourceID>{DS}</DataSourceID>
        <Table Schema="dbo" Table="{T}" />
        <Column IsWildCard="true" />
      </ColumnNullRatioProfileRequest>
      <ColumnStatisticsProfileRequest ID="StatisticsReq">
        <DataSourceID>{DS}</DataSourceID>
        <Table Schema="dbo" Table="{T}" />
        <Column IsWildCard="true" />
      </ColumnStatisticsProfileRequest>
      <ColumnLengthDistributionProfileRequest ID="LengthDistReq">
        <DataSourceID>{DS}</DataSourceID>
        <Table Schema="dbo" Table="{T}" />
        <Column IsWildCard="true" />
        <IgnoreLeadingSpace>false</IgnoreLeadingSpace>
        <IgnoreTrailingSpace>true</IgnoreTrailingSpace>
      </ColumnLengthDistributionProfileRequest>
      <ColumnValueDistributionProfileRequest ID="ValueDistReq">
        <DataSourceID>{DS}</DataSourceID>
        <Table Schema="dbo" Table="{T}" />
        <Column IsWildCard="true" />
        <Option>FrequentValues</Option>
        <FrequentValueThreshold>0.001</FrequentValueThreshold>
      </ColumnValueDistributionProfileRequest>
      <ColumnPatternProfileRequest ID="PatternReq">
        <DataSourceID>{DS}</DataSourceID>
        <Table Schema="dbo" Table="{T}" />
        <Column IsWildCard="true" />
        <MaxNumberOfPatterns>20</MaxNumberOfPatterns>
        <PercentageDataCoverageDesired>95</PercentageDataCoverageDesired>
        <CaseSensitive>false</CaseSensitive>
        <Delimiters> \\t\\r\\n</Delimiters>
        <Symbols>,.;:-"'`~=&amp;/\\\\@!?()&lt;&gt;[]{}|#*^%</Symbols>
        <TagTableName />
      </ColumnPatternProfileRequest>
      <CandidateKeyProfileRequest ID="KeyReq">
        <DataSourceID>{DS}</DataSourceID>
        <Table Schema="dbo" Table="{T}" />
        <KeyColumns>
          <Column IsWildCard="true" />
        </KeyColumns>
        <ThresholdSetting>Specified</ThresholdSetting>
        <KeyStrengthThreshold>0.95</KeyStrengthThreshold>
        <VerifyOutputInFastMode>false</VerifyOutputInFastMode>
        <MaxNumberOfViolations>100</MaxNumberOfViolations>
      </CandidateKeyProfileRequest>
    </Requests>
  </DataProfileInput>
  <DataProfileOutput>
    <Profiles />
  </DataProfileOutput>
</DataProfile>'''

def paquete(nombre, tablas):
    ds = g()
    cms = ['''    <DTS:ConnectionManager
      DTS:refId="Package.ConnectionManagers[KentFoods]"
      DTS:CreationName="ADO.NET:System.Data.SqlClient.SqlConnection, System.Data, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
      DTS:DTSID="%s"
      DTS:ObjectName="KentFoods">
      <DTS:ObjectData>
        <DTS:ConnectionManager
          DTS:ConnectionString="Data Source=.;Initial Catalog=KentFoods;Integrated Security=True;TrustServerCertificate=True;" />
      </DTS:ObjectData>
    </DTS:ConnectionManager>''' % ds]
    execs, nodes = [], []
    for i, (tabla, tag) in enumerate(tablas):
        f = f'{tabla.upper()}_Profile.xml'
        cms.append(f'''    <DTS:ConnectionManager
      DTS:refId="Package.ConnectionManagers[{f}]"
      DTS:CreationName="FILE"
      DTS:DTSID="{g()}"
      DTS:ObjectName="{f}">
      <DTS:ObjectData>
        <DTS:ConnectionManager
          DTS:FileUsageType="1"
          DTS:ConnectionString="{os.path.normpath(os.path.join(RES, f))}" />
      </DTS:ObjectData>
    </DTS:ConnectionManager>''')
        execs.append(f'''    <DTS:Executable
      DTS:refId="Package\\Perfil {tag}"
      DTS:CreationName="Microsoft.DataProfilingTask"
      DTS:Description="Perfilamiento de dbo.{tabla}"
      DTS:DTSID="{g()}"
      DTS:ExecutableType="Microsoft.DataProfilingTask"
      DTS:LocaleID="-1"
      DTS:ObjectName="Perfil {tag}"
      DTS:ThreadHint="0">
      <DTS:Variables />
      <DTS:ObjectData>
        <DataProfilingTaskData
          Destination="{f}"
          OverwriteDestination="True">
          <ProfileInput>
<![CDATA[{PROFILE.replace("{DS}", ds).replace("{T}", tabla)}]]>
</ProfileInput>
        </DataProfilingTaskData>
      </DTS:ObjectData>
    </DTS:Executable>''')
        col, row = i % 2, i // 2
        nodes.append(f'<NodeLayout Size="200,42.6666666667" Id="Package\\Perfil {tag}" TopLeft="{30 + 260 * col},{30 + 78 * row}" />')
    layout = ('<?xml version="1.0"?><Objects Version="8"><Package design-time-name="Package"><LayoutInfo>'
              '<GraphLayout Capacity="8" xmlns="clr-namespace:Microsoft.SqlServer.IntegrationServices.Designer.Model.Serialization;'
              'assembly=Microsoft.SqlServer.IntegrationServices.Graph">' + ''.join(nodes) + '</GraphLayout></LayoutInfo></Package></Objects>')
    return f'''<?xml version="1.0"?>
<DTS:Executable xmlns:DTS="www.microsoft.com/SqlServer/Dts"
  DTS:refId="Package"
  DTS:CreationDate="10/6/2026 12:00:00 PM"
  DTS:CreationName="Microsoft.Package"
  DTS:CreatorComputerName="LOCAL"
  DTS:CreatorName="Grupo 7"
  DTS:DTSID="{g()}"
  DTS:ExecutableType="Microsoft.Package"
  DTS:LastModifiedProductVersion="15.0.2000.166"
  DTS:LocaleID="1034"
  DTS:ObjectName="{nombre}"
  DTS:PackageType="5"
  DTS:VersionBuild="1"
  DTS:VersionGUID="{g()}">
  <DTS:Property DTS:Name="PackageFormatVersion">8</DTS:Property>
  <DTS:ConnectionManagers>
{chr(10).join(cms)}
  </DTS:ConnectionManagers>
  <DTS:Variables />
  <DTS:Executables>
{chr(10).join(execs)}
  </DTS:Executables>
  <DTS:DesignTimeProperties><![CDATA[{layout}]]></DTS:DesignTimeProperties>
</DTS:Executable>
'''

for nombre, tablas in PAQUETES:
    with open(os.path.join(PROJ, nombre + '.dtsx'), 'w', encoding='utf-8-sig', newline='\r\n') as fh:
        fh.write(paquete(nombre, tablas))

dts = ''.join(f'''<DtsPackage FormatVersion="8"><Name>{n}.dtsx</Name><FullPath>{n}.dtsx</FullPath><References /></DtsPackage>''' for n, _ in PAQUETES)
dtproj = f'''<?xml version="1.0" encoding="utf-8"?>
<Project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><DeploymentModel>Package</DeploymentModel><ProductVersion>15.0.2000.166</ProductVersion><SchemaVersion>9.0.1.0</SchemaVersion><State>$base64$PFNvdXJjZUNvbnRyb2xJbmZvIHhtbG5zOnhzZD0iaHR0cDovL3d3dy53My5vcmcvMjAwMS9YTUxTY2hlbWEiIHhtbG5zOnhzaT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS9YTUxTY2hlbWEtaW5zdGFuY2UiPg0KICA8RW5hYmxlZD5mYWxzZTwvRW5hYmxlZD4NCiAgPFByb2plY3ROYW1lPjwvUHJvamVjdE5hbWU+DQogIDxBdXhQYXRoPjwvQXV4UGF0aD4NCiAgPExvY2FsUGF0aD48L0xvY2FsUGF0aD4NCiAgPFByb3ZpZGVyPjwvUHJvdmlkZXI+DQo8L1NvdXJjZUNvbnRyb2xJbmZvPg==</State><Database><Name>KentFoods_Profiler.database</Name><FullPath>KentFoods_Profiler.database</FullPath></Database><DataSources /><DataSourceViews /><DeploymentModelSpecificContent><Manifest><DTSPackages>{dts}</DTSPackages></Manifest></DeploymentModelSpecificContent><ControlFlowParts /><Miscellaneous /><Configurations><Configuration><Name>Development</Name><Options><OutputPath>bin</OutputPath><ConnectionMappings /><ConnectionProviderMappings /><ConnectionSecurityMappings /><DatabaseStorageLocations /><TargetServerVersion>SQLServer2019</TargetServerVersion><AzureMode>false</AzureMode><LinkedAzureTenantId /><LinkedAzureAccountId /><LinkedAzureSSISIR /><LinkedAzureStorage /><RemoteExecutionFolder /><ParameterConfigurationValues /></Options></Configuration></Configurations></Project>
'''
with open(os.path.join(PROJ, 'KentFoods_Profiler.dtproj'), 'w', encoding='utf-8-sig', newline='\r\n') as fh:
    fh.write(dtproj)

db = ('<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xmlns:dwd="http://schemas.microsoft.com/DataWarehouse/Designer/1.0" dwd:design-time-name="%s" '
      'xmlns="http://schemas.microsoft.com/analysisservices/2003/engine"><ID>KentFoods_Profiler</ID><Name>KentFoods_Profiler</Name>'
      '<CreatedTimestamp>0001-01-01T00:00:00Z</CreatedTimestamp><LastSchemaUpdate>0001-01-01T00:00:00Z</LastSchemaUpdate>'
      '<LastProcessed>0001-01-01T00:00:00Z</LastProcessed><State>Unprocessed</State><LastUpdate>0001-01-01T00:00:00Z</LastUpdate>'
      '<DataSourceImpersonationInfo><ImpersonationMode>Default</ImpersonationMode><ImpersonationInfoSecurity>Unchanged</ImpersonationInfoSecurity>'
      '</DataSourceImpersonationInfo></Database>') % str(uuid.uuid4())
with open(os.path.join(PROJ, 'KentFoods_Profiler.database'), 'w', encoding='utf-8-sig') as fh:
    fh.write(db)
with open(os.path.join(PROJ, 'Project.params'), 'w', encoding='utf-8-sig') as fh:
    fh.write('<?xml version="1.0"?>\r\n<SSIS:Parameters xmlns:SSIS="www.microsoft.com/SqlServer/SSIS" />')
with open(os.path.join(RES, 'LEEME.txt'), 'w', encoding='utf-8') as fh:
    fh.write('Los archivos XML generados por los Data Profiling Task se guardan en esta carpeta.\r\n'
             'Se abren con Data Profile Viewer (DataProfileViewer.exe).\r\n')

pg, sg = '{' + str(uuid.uuid4()).upper() + '}', '{' + str(uuid.uuid4()).upper() + '}'
sln = f'''Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 16
VisualStudioVersion = 16.0.31624.102
MinimumVisualStudioVersion = 10.0.40219.1
Project("{{159641D6-6404-4A2A-AE62-294DE0FE8301}}") = "KentFoods_Profiler", "KentFoods_Profiler\\KentFoods_Profiler.dtproj", "{pg}"
EndProject
Global
\tGlobalSection(SolutionConfigurationPlatforms) = preSolution
\t\tDevelopment|Default = Development|Default
\tEndGlobalSection
\tGlobalSection(ProjectConfigurationPlatforms) = postSolution
\t\t{pg}.Development|Default.ActiveCfg = Development
\t\t{pg}.Development|Default.Build.0 = Development
\tEndGlobalSection
\tGlobalSection(SolutionProperties) = preSolution
\t\tHideSolutionNode = FALSE
\tEndGlobalSection
\tGlobalSection(ExtensibilityGlobals) = postSolution
\t\tSolutionGuid = {sg}
\tEndGlobalSection
EndGlobal
'''
with open(os.path.join(REPO, 'avance2', 'ssis', 'KentFoods_Profiler.sln'), 'w', encoding='utf-8-sig', newline='\r\n') as fh:
    fh.write(sln)
print('Proyecto generado en', PROJ)

