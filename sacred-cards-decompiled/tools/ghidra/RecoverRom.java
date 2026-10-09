// Export drafts only for explicitly seeded AY7E functions.
// @category AY7E
import ghidra.app.script.GhidraScript;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import ghidra.app.cmd.function.CreateFunctionCmd;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.lang.Register;
import ghidra.program.model.lang.RegisterValue;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.*;
import java.math.BigInteger;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.io.*;

public class RecoverRom extends GhidraScript {
    private long number(String s) { return Long.parseUnsignedLong(s.replace("0x", ""),16); }
    private String csv(String s) { return "\"" + s.replace("\"", "\"\"").replace("\n", " ").replace("\r", " ") + "\""; }
    private void ram(String name,long start,long size,boolean vol) throws Exception {
        MemoryBlock b=currentProgram.getMemory().createUninitializedBlock(name,toAddr(start),size,false);
        b.setRead(true);b.setWrite(true);b.setExecute(false);b.setVolatile(vol);
    }
    @Override public void run() throws Exception {
        String[] args=getScriptArgs();Path input=Path.of(args[0]),out=Path.of(args[1]);
        Files.createDirectories(out.resolve("functions"));
        Memory memory=currentProgram.getMemory();
        for(MemoryBlock block:memory.getBlocks()){block.setWrite(false);block.setExecute(true);}
        ram("EWRAM",0x02000000L,0x40000,false);ram("IWRAM",0x03000000L,0x8000,false);
        ram("IO",0x04000000L,0x400,true);ram("PAL",0x05000000L,0x400,true);
        ram("VRAM",0x06000000L,0x18000,true);ram("OAM",0x07000000L,0x400,true);
        ram("SRAM",0x0E000000L,0x10000,true);
        Register tmode=currentProgram.getRegister("TMode");
        AddressSet allowed=new AddressSet();List<Address> rangeStarts=new ArrayList<>();
        for(String line:Files.readAllLines(input.resolve("ranges.tsv"))){
            String[] p=line.split("\t");Address start=toAddr(number(p[0])),end=toAddr(number(p[1]));
            currentProgram.getProgramContext().setValue(tmode,start,end,p[2].equals("thumb")?BigInteger.ONE:BigInteger.ZERO);
            allowed.add(start,end);rangeStarts.add(start);
        }
        new DisassembleCommand(allowed,allowed,false).applyTo(currentProgram,monitor);
        // ARM7 interworking epilogues pop the saved LR into a low register,
        // then BX that register. Mark only this exact reviewed listing pattern.
        for(String line:Files.readAllLines(input.resolve("returns.tsv"))){
            Instruction ins=getInstructionAt(toAddr(number(line)));
            if(ins!=null)ins.setFlowOverride(FlowOverride.RETURN);
        }
        for(String line:Files.readAllLines(input.resolve("jumps.tsv"))){
            String[] p=line.split("\t");Address from=toAddr(number(p[0])),to=toAddr(number(p[1]));
            currentProgram.getReferenceManager().addMemoryReference(from,to,RefType.COMPUTED_JUMP,SourceType.USER_DEFINED,0);
        }
        List<String[]> seeds=new ArrayList<>();
        for(String line:Files.readAllLines(input.resolve("functions.tsv")))seeds.add(line.split("\t"));
        // Copied code can acquire a data type from its ROM-source references.
        // Retry explicitly reviewed missing roots after clearing their reviewed
        // instruction span, with an explicit initial ARM/Thumb context.
        for(String[] p:seeds){
            Address entry=toAddr(number(p[0]));
            if(getInstructionAt(entry)!=null)continue;
            println("AY7E retry reviewed entry "+entry+" data="+getDataContaining(entry));
            AddressRange range=allowed.getRangeContaining(entry);
            currentProgram.getListing().clearCodeUnits(entry,range.getMaxAddress(),false);
            DisassembleCommand command=new DisassembleCommand(entry,allowed,true);
            command.setInitialContext(new RegisterValue(tmode,p[1].equals("thumb")?BigInteger.ONE:BigInteger.ZERO));
            command.applyTo(currentProgram,monitor);
        }
        for(String line:Files.readAllLines(input.resolve("returns.tsv"))){
            Instruction ins=getInstructionAt(toAddr(number(line)));
            if(ins!=null)ins.setFlowOverride(FlowOverride.RETURN);
        }
        // Establish every entry point before expanding function bodies, so tail
        // calls stop at other known entries rather than absorb their functions.
        for(String[] p:seeds){
            Address entry=toAddr(number(p[0]));
            if(getInstructionAt(entry)==null)continue;
            if(getFunctionAt(entry)==null)currentProgram.getFunctionManager().createFunction(p[2],entry,new AddressSet(entry),SourceType.USER_DEFINED);
            else getFunctionAt(entry).setName(p[2],SourceType.USER_DEFINED);
        }
        for(String[] p:seeds){
            Function f=getFunctionAt(toAddr(number(p[0])));
            if(f!=null)CreateFunctionCmd.fixupFunctionBody(currentProgram,f,monitor);
        }
        println("AY7E: seeded "+seeds.size()+" function entries; starting draft C export");
        DecompInterface decompiler=new DecompInterface();
        DecompileOptions options=new DecompileOptions();options.grabFromProgram(currentProgram);
        decompiler.setOptions(options);decompiler.toggleCCode(true);decompiler.toggleSyntaxTree(true);
        if(!decompiler.openProgram(currentProgram))throw new IOException(decompiler.getLastMessage());
        int done=0,failed=0;
        try(BufferedWriter manifest=Files.newBufferedWriter(out.resolve("functions.csv"),StandardCharsets.UTF_8)){
            manifest.write("address,name,status,body_bytes,error,file\n");
            for(String[] p:seeds){
                monitor.checkCancelled();Function f=getFunctionAt(toAddr(number(p[0])));
                String name=p[2],status="missing_function",error="",filename="";long size=0;
                if(f!=null){
                    size=f.getBody().getNumAddresses();
                    DecompileResults result=decompiler.decompileFunction(f,30,monitor);
                    error=result.getErrorMessage();
                    if(result.decompileCompleted()&&result.getDecompiledFunction()!=null){
                        filename="functions/"+p[0]+"_"+name+".c";
                        String c=result.getDecompiledFunction().getC();
                        String header="/* AUTO-GENERATED GHIDRA DRAFT. Not reviewed, execution-compared, or compiler-matched.\n * Native entry 0x"+p[0]+". Review inferred types, calling convention, function boundaries, and warnings.\n */\n\n";
                        Files.writeString(out.resolve(filename),header+c,StandardCharsets.UTF_8);
                        status=c.contains("WARNING")?"draft_with_warnings":"draft";done++;
                    } else {status="decompile_failed";failed++;}
                } else failed++;
                manifest.write(p[0]+","+csv(name)+","+status+","+size+","+csv(error)+","+filename+"\n");
                if((done+failed)%100==0){manifest.flush();println("AY7E progress: "+done+" drafts, "+failed+" failures");}
            }
        } finally {decompiler.dispose();}
        println("AY7E DONE: "+done+" drafts, "+failed+" failures");
    }
}
