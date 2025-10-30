import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Path;

// Setup of compiler: Stage0 compiler is an application in the world
// of the bootstrap compiler.  It uses the modules tcljc-(rt|core) and
// tcljx-(alpha|compiler) from STAGE0_MDIR running in a dedicated
// class loader.
//
// Setup for application being compiled: Starts with an empty class
// loader into which only the module STAGE1/tcljc.rt is installed.
// That is, the application must provide its own tcljx.core and
// tcljx.compiler modules.
//
// Output: Generated application classes depend on
// tcljx-(rt|core|compiler) to run.

class TcljStage0 {
  static final String stageName = "stage0";
  
  static Path stage0Source(String moduleName) {
    return Shared.modulePath(stageName, moduleName);
  }
  static URL stage0Module(String moduleName) throws Exception {
    //System.out.println("[module] "+stage0Source(moduleName).toUri().toURL());
    return stage0Source(moduleName).toUri().toURL();
  }
  
  static Method stage0Main() throws Exception {
    var urls = new URL[] {
      stage0Module("tcljc.rt"),
      stage0Module("tcljc.core"),
      stage0Module("tcljx.alpha"),
      stage0Module("tcljx.compiler") };
    var parent = ClassLoader.getPlatformClassLoader();
    return Shared.mainMethodOf(new URLClassLoader(stageName, urls, parent),
                               "tcljx.main");
  }

  static String[] stage0Args(String[] cmdlineArgs) {
    return Shared.concat(new String[] {
        "--deterministic",
        "-s", Shared.modulePath("stage1", "tcljx.rt").toString() },
      cmdlineArgs);
  }
  
  public static final void main(String... args) throws Exception {
    var compileArgs = stage0Args(args);
    System.out.println("[TcljStage0] "+String.join(" ", compileArgs));
    stage0Main().invoke(null, (Object)compileArgs);
  }
}
