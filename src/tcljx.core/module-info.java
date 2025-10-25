module tcljx.core {
  requires transitive tcljx.rt;
  // requires transitive java.sql;  // for resultseq-seq
  requires static java.xml;  // for clojure.xml
  requires static java.sql;  // for clojure.instant
  
  exports clojure.core;
  exports clojure.core.protocols;
  exports clojure.string;
  exports clojure.uuid;
  exports clojure.math;
  exports clojure.java.io;

  exports clojure.datafy;
  exports clojure.edn;
  exports clojure.set;
  exports clojure.test;
  exports clojure.stacktrace;
  exports clojure.walk;
  exports clojure.template;
  exports clojure.instant;
  exports clojure.xml;
  exports clojure.zip;
}
