// Export existing reviewed bodies without modifying or reanalyzing the program.
// @category AY7E
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.nio.file.*;
import java.io.*;
public class ExportFunctionBodies extends GhidraScript {
    @Override public void run() throws Exception {
        Path out=Path.of(getScriptArgs()[0]);Files.createDirectories(out);
        try(BufferedWriter writer=Files.newBufferedWriter(out.resolve("native-function-bodies.csv"))) {
            writer.write("function,start,end_inclusive\n");
            FunctionIterator functions=currentProgram.getFunctionManager().getFunctions(true);
            while(functions.hasNext()) {
                Function f=functions.next();AddressRangeIterator ranges=f.getBody().getAddressRanges();
                while(ranges.hasNext()) {
                    AddressRange r=ranges.next();
                    writer.write(f.getEntryPoint()+","+r.getMinAddress()+","+r.getMaxAddress()+"\n");
                }
            }
        }
        println("AY7E existing native function bodies exported");
    }
}
