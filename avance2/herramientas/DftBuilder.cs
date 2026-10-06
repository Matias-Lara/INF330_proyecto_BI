using System;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;

namespace EtlSupport
{
    // Crea una tarea Data Flow:  OLE DB Source (consulta SQL) -> OLE DB Destination (carga rápida, mapeo por nombre)
    public static class DftBuilder
    {
        public static TaskHost Add(Package pkg, string name, string desc,
                                   ConnectionManager srcCm, string sql,
                                   ConnectionManager dstCm, string table, out int mapped)
        {
            TaskHost th = (TaskHost)pkg.Executables.Add("STOCK:PipelineTask");
            th.Name = name;
            th.Description = desc;
            MainPipe pipe = (MainPipe)th.InnerObject;

            // ---- origen
            IDTSComponentMetaData100 src = pipe.ComponentMetaDataCollection.New();
            src.ComponentClassID = "Microsoft.OLEDBSource";
            CManagedComponentWrapper si = src.Instantiate();
            si.ProvideComponentProperties();
            src.Name = "SRC_" + table;
            src.RuntimeConnectionCollection[0].ConnectionManagerID = srcCm.ID;
            src.RuntimeConnectionCollection[0].ConnectionManager = DtsConvert.GetExtendedInterface(srcCm);
            si.SetComponentProperty("AccessMode", 2);              // SQL command
            si.SetComponentProperty("SqlCommand", sql);
            si.AcquireConnections(null);
            si.ReinitializeMetaData();
            si.ReleaseConnections();

            // ---- destino
            IDTSComponentMetaData100 dst = pipe.ComponentMetaDataCollection.New();
            dst.ComponentClassID = "Microsoft.OLEDBDestination";
            CManagedComponentWrapper di = dst.Instantiate();
            di.ProvideComponentProperties();
            dst.Name = "DST_" + table;
            dst.RuntimeConnectionCollection[0].ConnectionManagerID = dstCm.ID;
            dst.RuntimeConnectionCollection[0].ConnectionManager = DtsConvert.GetExtendedInterface(dstCm);
            di.SetComponentProperty("AccessMode", 3);              // Table - fast load
            di.SetComponentProperty("OpenRowset", "[dbo].[" + table + "]");
            di.SetComponentProperty("FastLoadOptions", "TABLOCK,CHECK_CONSTRAINTS");
            di.SetComponentProperty("FastLoadMaxInsertCommitSize", 10000);

            IDTSPath100 path = pipe.PathCollection.New();
            path.AttachPathAndPropagateNotifications(src.OutputCollection[0], dst.InputCollection[0]);

            di.AcquireConnections(null);
            di.ReinitializeMetaData();

            IDTSInput100 input = dst.InputCollection[0];
            IDTSVirtualInput100 vi = input.GetVirtualInput();
            foreach (IDTSVirtualInputColumn100 vcol in vi.VirtualInputColumnCollection)
                di.SetUsageType(input.ID, vi, vcol.LineageID, DTSUsageType.UT_READONLY);

            mapped = 0;
            foreach (IDTSInputColumn100 icol in input.InputColumnCollection)
            {
                IDTSExternalMetadataColumn100 ext = null;
                foreach (IDTSExternalMetadataColumn100 e in input.ExternalMetadataColumnCollection)
                {
                    if (string.Equals(e.Name, icol.Name, StringComparison.OrdinalIgnoreCase)) { ext = e; break; }
                }
                if (ext == null)
                    throw new InvalidOperationException("[" + name + "] la columna '" + icol.Name + "' no existe en " + table);
                di.MapInputColumn(input.ID, icol.ID, ext.ID);
                mapped++;
            }
            di.ReleaseConnections();
            return th;
        }
    }
}
