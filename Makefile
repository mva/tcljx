JAVA_HOME ?= ~/local/jdk-classfile
BOOTSTRAP_MDIR ?= ../bootstrap-tcljc

JAVA_BIN=$(if $(JAVA_HOME),$(JAVA_HOME)/bin/,)
JAVA=$(JAVA_BIN)java
JAVAC=$(JAVA_BIN)javac
JAVAP=$(JAVA_BIN)javap

# Note: only textflow__terminal requires --enable-native-access
JAVA_OPTS=-p $(BOOTSTRAP_MDIR) --add-modules tcljc.core --enable-native-access=ALL-UNNAMED
TCLJC_OPTS=$(JAVA_OPTS) -m tcljc.compiler -s src/tcljx.compiler -s test/tcljx.compiler

#MAIN_NS=tcljx.alpha.textflow__terminal
MAIN_NS=tcljx.main
RUN_TESTS_NS=tcljx.run-tests

compile: support/DONE
	$(COMPILER_BOOT) -s src/tcljx.compiler -s test/tcljx.compiler $(RUN_TESTS_NS)
watch-and-compile: support/DONE
	$(COMPILER_BOOT) --watch -s src/tcljx.compiler -s test/tcljx.compiler $(RUN_TESTS_NS)


# $(DEST_DIR) matches the bootstrap(!) compiler's default destination
# directory
PROJECT_DIR ?= $(notdir $(PWD))
TMP_USER=/tmp/$(USER)
DEST_DIR=$(TMP_USER)/tcljc/$(PROJECT_DIR)
TEST_OUT=$(TMP_USER)/tcljx/$(PROJECT_DIR).test


# see https://egahlin.github.io/2023/05/30/views.html
JFR=$(JAVA_BIN)jfr
JFR_RECORDING=/tmp/recording.jfr
run-jfr: compile
	$(JAVA) -XX:StartFlightRecording:filename=$(JFR_RECORDING),method-timing="tcljx.classgen.util.LocalVariable" -cp ../bootstrap-tcljc/tcljc.rt:../bootstrap-tcljc/tcljc.core:$(DEST_DIR) $(RUN_TESTS_NS).___
#	$(JAVA) -XX:StartFlightRecording:filename=$(JFR_RECORDING),settings=profile $(JAVA_OPTS) -cp $(DEST_DIR) $(MAIN_NS).___ $(ARGS)
#	$(JFR) summary $(JFR_RECORDING)
#	$(JFR) print --events jdk.MethodTrace --stack-depth 20 $(JFR_RECORDING)
#	$(JFR) print --events jdk.MethodTiming --stack-depth 20 $(JFR_RECORDING)
#	@$(JFR) view allocation-by-site $(JFR_RECORDING)
#	@$(JFR) view hot-methods $(JFR_RECORDING)
	@$(JFR) view method-timing $(JFR_RECORDING)

# Call with "make test TEST=<scope>" (with <scope> being "ns-name" or
# "ns-name/var-name") to only run tests from the given namespace or
# var.  Only call this after compile, possibly while one of the
# watch-and-xxx targets is running.
test: support/DONE
	$(JAVA) -p ../bootstrap-tcljc --add-modules tcljc.core -cp $(DEST_DIR) $(RUN_TESTS_NS).___
#	$(COMPILER_BOOT) -s src/tcljx.compiler -s test/tcljx.compiler $(RUN_TESTS_NS)/run
watch-and-test: support/DONE
	$(COMPILER_BOOT) --watch -s src/tcljx.compiler -s test/tcljx.compiler $(RUN_TESTS_NS)/run


clean:
	rm -rf support/DONE support/*.class "$(DEST_DIR)"/* "/tmp/$(USER)"/tcljx* *.class textflow__termios.out hs_err_pid*.log replay_pid*.log

print-line-count:
	find src/tcljx.compiler/tcljx -name "*.cljt" | grep -v src/tcljx.compiler/tcljx/alpha/ | xargs wc -l | sort -n

print-lines-of-code:
	find src/tcljx.compiler/tcljx -name "*.cljt" | grep -v src/tcljx.compiler/tcljx/alpha/ | xargs grep -v '^ *\($$\|;\)' | wc -l

.PHONY: compile watch-and-compile test watch-and-test clean



textflow__termios.out: src/tcljx.compiler/tcljx/alpha/textflow__termios.c
	gcc -Wall -o $@ $^

src/tcljx.compiler/tcljx/alpha/textflow__termios.cljt: textflow__termios.out
	./$^ >$@

# ------------------------------------------------------------------------
# Support for strict class loader isolation between bootstrapping
# compiler and application being compiled.

support/DONE: support/*.java
	$(JAVAC) -d support $^
	touch $@

COMPILER_BOOT=$(JAVA) -cp support TcljBoot
COMPILER_STAGE0=$(BUILD_JAVA_ONCE) -cp support TcljStage0

# ------------------------------------------------------------------------
# Create module directory $(STAGE0_MDIR) using the bootstrap
# compiler's compiles and the bootstrap compiler's output for
# tcljx.main

BUILD_JAVAC=$(JAVAC) --release 21
BUILD_JAVA_ONCE=$(JAVA) -XX:TieredStopAtLevel=1
BUILD_JAR=$(JAVA_BIN)jar
TCLJX_MAIN_NS=tcljx.main

# Note: Compilation of clojure.instant depends on module java.sql
STAGE0=$(TMP_USER)/tcljx-stage0
STAGE0_MDIR=$(STAGE0).mdir

$(STAGE0_MDIR)/tcljx-compiler.jar: support/DONE
	mkdir -p $(STAGE0_MDIR)
# tcljc.rt / tcljc-rt.jar
	cp -r $(BOOTSTRAP_MDIR)/tcljc.rt $(STAGE0_MDIR)
	$(BUILD_JAR) --create --file=$(STAGE0_MDIR)/tcljc-rt.jar -C $(STAGE0_MDIR)/tcljc.rt .
	rm -rf $(STAGE0_MDIR)/tcljc.rt
# tcljc.core / tcljc-core.jar
	cp -r $(BOOTSTRAP_MDIR)/tcljc.core $(STAGE0_MDIR)
	$(BUILD_JAR) --create --file=$(STAGE0_MDIR)/tcljc-core.jar -C $(STAGE0_MDIR)/tcljc.core .
	rm -rf $(STAGE0_MDIR)/tcljc.core
# tcljx.compiler / tcljx-compiler.jar
	$(COMPILER_BOOT) -d $(STAGE0_MDIR)/tcljx.compiler -s src/tcljx.compiler $(TCLJX_MAIN_NS)
	$(BUILD_JAVAC) -p $(STAGE0_MDIR) -d $(STAGE0_MDIR)/tcljx.compiler src/tcljx.compiler/module-info.java
	$(BUILD_JAR) --create --file=$(STAGE0_MDIR)/tcljx-compiler.jar --main-class=$(TCLJX_MAIN_NS).___ -C $(STAGE0_MDIR)/tcljx.compiler .
	rm -rf $(STAGE0_MDIR)/tcljx.compiler

# ------------------------------------------------------------------------
# Use bootstrapped compiler to build modules for runtime, core
# library, and compiler.  Build the module directories in
# $(STAGE1_CLASSES).(rt|core|compiler)

STAGE1=$(TMP_USER)/tcljx-stage1
STAGE1_CLASSES=$(STAGE1).cldir/tcljx

TCLJX_SOURCE_RT := $(sort $(wildcard src/tcljx.rt/*/lang/*.java)) src/tcljx.rt/module-info.java
$(STAGE1_CLASSES).rt/module-info.class: $(TCLJX_SOURCE_RT)
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	mkdir -p --mode 700 "$(TMP_USER)" "$(dir $@)"
	$(BUILD_JAVAC) -d "$(dir $@)" $^

TCLJX_SOURCE_CORE := $(sort $(wildcard src/tcljx.core/*/*.cljt srx/tcljc.core/*/*/*.cljt)) src/tcljx.core/module-info.java
$(STAGE1_CLASSES).core/module-info.class: $(STAGE1_CLASSES).rt/module-info.class $(TCLJX_SOURCE_CORE) $(STAGE0_MDIR)/tcljx-compiler.jar support/DONE
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	$(COMPILER_STAGE0) -d "$(dir $@)" -s src/tcljx.core clojure.core.all
	$(BUILD_JAVAC) -p $(dir $<) -d "$(dir $@)" src/tcljx.core/module-info.java

TCLJX_SOURCE_RTIOW := test/tcljx.compiler/tcljx/classgen/rtiow-ref.cljt
$(STAGE1_CLASSES).rtiow/ray.ppm: $(STAGE1_CLASSES).core/module-info.class $(TCLJX_SOURCE_RTIOW) support/DONE
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	$(COMPILER_STAGE0) -d $(STAGE1_CLASSES).rtiow -s $(STAGE1_CLASSES).rt -s $(STAGE1_CLASSES).core -s test/tcljx.compiler tcljx.classgen.rtiow-ref
	$(JAVA) -cp $(STAGE1_CLASSES).rt:$(dir $<):$(STAGE1_CLASSES).rtiow tcljx.classgen.rtiow-ref.___ >$@
	@echo "3cf6c9b9f93edb0de2bc24015c610d78  $@" | md5sum -c -

stage0-mdir: $(STAGE0_MDIR)/tcljx-compiler.jar
stage1-core: $(STAGE1_CLASSES).core/module-info.class
stage1-rtiow: $(STAGE1_CLASSES).rtiow/ray.ppm
