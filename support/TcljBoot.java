import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Path;

// Setup of compiler: Bootstrap compiler using its own modules
// bootstrap-(rt|core|compiler) and running in a dedicated class
// loader.
//
// Setup for application being compiled: Starts with an empty class
// loader into which bootstrap-(rt|core) are installed.  That is, the
// application requires the bootstrap compiler's core library.
//
// Output: Generated application classes depend on bootstrap-(rt|core)
// to run.

class TcljBoot {
  static final Path bootstrapMdir = Path.of("../bootstrap-tcljc");
  
  static Path bootstrapSource(String nameSuffix) {
    return bootstrapMdir.resolve("tcljc."+nameSuffix);
  }
  static URL bootstrapModule(String nameSuffix) throws Exception {
    return bootstrapSource(nameSuffix).toUri().toURL();
  }

  static Method bootstrapMain() throws Exception {
    var urls = new URL[] {
      bootstrapModule("rt"),
      bootstrapModule("core"),
      bootstrapModule("compiler") };
    var parent = ClassLoader.getPlatformClassLoader();
    return Shared.mainMethodOf(new URLClassLoader("bootstrap", urls, parent),
                               "tcljc.main");
  }

  static String[] bootstrapArgs(String[] cmdlineArgs) {
    return Shared.concat(new String[] {
        "-s", bootstrapSource("rt").toString(),
        "-s", bootstrapSource("core").toString() },
      cmdlineArgs);
  }
  
  public static final void main(String... args) throws Exception {
    var compileArgs = bootstrapArgs(args);
    System.out.println("[TcljBoot] "+String.join(" ", compileArgs)+" ...");
    bootstrapMain().invoke(null, (Object)compileArgs);
  }
}
