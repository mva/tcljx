import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Path;

// Setup of compiler: Stage1 compiler is an application in the world
// of the bootstrap compiler.  It uses the modules tcljc-(rt|core) and
// tcljx-compiler from STAGE1_MDIR running in a dedicated class
// loader.
//
// Setup for application being compiled: Starts with an empty class
// loader into which only the module STAGE2/tcljc.rt is installed.
// That is, the application must provide its own tcljx.core and
// tcljx.compiler modules.
//
// Output: Generated application classes depend on
// tcljx-(rt|core|compiler) to run.

class TcljStage1 {
  static final String stageName = "stage1";
  
  static Path stage1Source(String moduleName) {
    return Shared.modulePath(stageName, moduleName);
  }
  static URL stage1Module(String moduleName) throws Exception {
    System.out.println("[module] "+stage1Source(moduleName).toUri().toURL());
    return stage1Source(moduleName).toUri().toURL();
  }
  
  static Method stage1Main() throws Exception {
    var urls = new URL[] {
      stage1Module("tcljx.rt"),
      stage1Module("tcljx.core"),
      stage1Module("tcljx.compiler") };
    var parent = ClassLoader.getPlatformClassLoader();
    return Shared.mainMethodOf(new URLClassLoader(stageName, urls, parent),
                               "tcljx.main");
  }

  static String[] stage1Args(String[] cmdlineArgs) {
    return Shared.concat(new String[] {
        "--deterministic",
        "-s", Shared.modulePath("stage2", "tcljx.rt").toString() },
      cmdlineArgs);
  }
  
  public static final void main(String... args) throws Exception {
    var compileArgs = stage1Args(args);
    System.out.println("[TcljStage1] "+String.join(" ", compileArgs));
    stage1Main().invoke(null, (Object)compileArgs);
  }
}
