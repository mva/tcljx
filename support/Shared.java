import java.lang.reflect.Method;
import java.nio.file.Path;

class Shared {
  
  static String[] concat(String[] a, String[] b) {
    var x = new String[a.length + b.length];
    System.arraycopy(a, 0, x, 0, a.length);
    System.arraycopy(b, 0, x, a.length, b.length);
    return x;
  }

  static Path modulePath(String stageName, String moduleName) { // tcljx.foo
    return Path.of(System.getProperty("java.io.tmpdir"),
                   System.getProperty("user.name"),
                   "tcljx-"+stageName+".mdir-xpl",
                   moduleName);
  }

  static Method mainMethodOf(ClassLoader loader, String nmspName) throws Exception {
    var nmspCapstone = Class.forName(nmspName+".___", true, loader);
    return nmspCapstone.getDeclaredMethod("main", String.class.arrayType());
  }
}
