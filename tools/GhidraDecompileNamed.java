// Headless Ghidra helper used during clean-room behavioral research.
// Usage: -postScript GhidraDecompileNamed.java name-fragment [...]

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;

public class GhidraDecompileNamed extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] fragments = getScriptArgs();
        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        for (Function function : currentProgram.getFunctionManager().getFunctions(true)) {
            boolean selected = fragments.length == 0;
            for (String fragment : fragments) {
                if (function.getName().contains(fragment)) {
                    selected = true;
                    break;
                }
            }
            if (!selected) {
                continue;
            }
            DecompileResults result = decompiler.decompileFunction(function, 120, monitor);
            println("\n===== " + function.getName() + " @ " + function.getEntryPoint() + " =====");
            if (result.decompileCompleted()) {
                println(result.getDecompiledFunction().getC());
            } else {
                println("Decompile failed: " + result.getErrorMessage());
            }
        }
        decompiler.dispose();
    }
}
