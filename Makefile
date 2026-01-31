JAVA_HOME ?= ~/local/jdk-classfile
BOOTSTRAP_MDIR ?= ../bootstrap-tcljc

JAVA_BIN=$(if $(JAVA_HOME),$(JAVA_HOME)/bin/,)
JAVA=$(JAVA_BIN)java
JAVAC=$(JAVA_BIN)javac
JAVAP=$(JAVA_BIN)javap

JAVA_OPTS=-p $(BOOTSTRAP_MDIR) --add-modules tcljc.core

MAIN_NS=tcljx.main
RUN_TESTS_NS=tcljx.run-tests

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
	$(JAVA) -XX:StartFlightRecording:filename=$(JFR_RECORDING),method-timing="tcljx.nmspgen.util.LocalVariable" -cp ../bootstrap-tcljc/tcljc.rt:../bootstrap-tcljc/tcljc.core:$(DEST_DIR) $(RUN_TESTS_NS).___
#	$(JAVA) -XX:StartFlightRecording:filename=$(JFR_RECORDING),settings=profile $(JAVA_OPTS) -cp $(DEST_DIR) $(MAIN_NS).___ $(ARGS)
#	$(JFR) summary $(JFR_RECORDING)
#	$(JFR) print --events jdk.MethodTrace --stack-depth 20 $(JFR_RECORDING)
#	$(JFR) print --events jdk.MethodTiming --stack-depth 20 $(JFR_RECORDING)
#	@$(JFR) view allocation-by-site $(JFR_RECORDING)
#	@$(JFR) view hot-methods $(JFR_RECORDING)
	@$(JFR) view method-timing $(JFR_RECORDING)


clean:
	rm -rf support/DONE support/*.class "$(DEST_DIR)"/* "/tmp/$(USER)"/tcljx* *.class hs_err_pid*.log replay_pid*.log

print-line-count:
	find src/tcljx.compiler/tcljx -name "*.cljt" | grep -v src/tcljx.compiler/tcljx/alpha/ | xargs wc -l | sort -n

print-lines-of-code:
	find src/tcljx.compiler/tcljx -name "*.cljt" | grep -v src/tcljx.compiler/tcljx/alpha/ | xargs grep -v '^ *\($$\|;\)' | wc -l

.PHONY: compile watch-and-compile test watch-and-test clean


# ------------------------------------------------------------------------
# Support for strict class loader isolation between bootstrapping
# compiler and application being compiled.

support/DONE: support/*.java
	$(JAVAC) -d support $^
	touch $@

COMPILER_BOOT=$(JAVA) -cp support TcljBoot
COMPILER_STAGE0=$(BUILD_JAVA_ONCE) -cp support TcljStage0
COMPILER_STAGE1=$(BUILD_JAVA_ONCE) -cp support TcljStage1

TCLJX_SOURCE_RT := src/tcljx.rt/module-info.java \
  $(sort $(wildcard src/tcljx.rt/*/lang/*.java))
TCLJX_SOURCE_CORE := src/tcljx.core/module-info.java \
  $(sort $(wildcard src/tcljx.core/*/*.cljt src/tcljx.core/*/*/*.cljt)) 
TCLJX_SOURCE_ALPHA := src/tcljx.core/module-info.java \
  $(sort $(wildcard src/tcljx.alpha/*/*.cljt src/tcljx.alpha/*/*/*.cljt)) 
TCLJX_SOURCE_COMPILER := src/tcljx.compiler/module-info.java \
  $(sort $(wildcard src/tcljx.compiler/*/*.cljt src/tcljx.compiler/*/*/*.cljt)) 
TCLJX_SOURCE_RTIOW := test/tcljx.compiler/tcljx/nmspgen/rtiow-ref.cljt

# ------------------------------------------------------------------------
# Create module directory $(STAGE0_MDIR) using the bootstrap
# compiler's compiles and the bootstrap compiler's output for
# tcljx.main

BUILD_JAVAC=$(JAVAC) --release 21
BUILD_JAVA_ONCE=$(JAVA) -XX:TieredStopAtLevel=1
BUILD_JAR=$(JAVA_BIN)jar
TCLJX_MAIN_NS=tcljx.main


STAGE0_MDIR=$(TMP_USER)/tcljx-stage0.mdir-xpl

# Note: Compilation of clojure.instant depends on module java.sql
$(STAGE0_MDIR)/DONE: $(TCLJX_SOURCE_COMPILER) support/DONE
	mkdir -p --mode 700 $(STAGE0_MDIR)
# tcljc.rt / tcljc-rt.jar
	cp -r $(BOOTSTRAP_MDIR)/tcljc.rt $(STAGE0_MDIR)
# tcljc.core / tcljc-core.jar
	cp -r $(BOOTSTRAP_MDIR)/tcljc.core $(STAGE0_MDIR)
# tcljx.alpha / tcljx-alpha.jar
	$(COMPILER_BOOT) -d $(STAGE0_MDIR)/tcljx.alpha -s src/tcljx.alpha tcljx.alpha.all
	$(BUILD_JAVAC) -p $(STAGE0_MDIR) -d $(STAGE0_MDIR)/tcljx.alpha src/tcljx.alpha/module-info.java
# tcljx.compiler / tcljx-compiler.jar
	$(COMPILER_BOOT) -d $(STAGE0_MDIR)/tcljx.compiler -s $(STAGE0_MDIR)/tcljx.alpha -s src/tcljx.compiler $(TCLJX_MAIN_NS)
	$(BUILD_JAVAC) -p $(STAGE0_MDIR) -d $(STAGE0_MDIR)/tcljx.compiler src/tcljx.compiler/module-info.java
	touch $@

# ------------------------------------------------------------------------
# Use bootstrapped compiler to build modules for core library and
# compiler.  Build the module directories in
# $(STAGE1_MDIR).(rt|core|compiler).  Note: STAGE1_MDIR and
# STAGE1_MINFO_RT must be defined before target `test` and
# `watch-and-test`.

STAGE1_MDIR=$(TMP_USER)/tcljx-stage1.mdir-xpl

STAGE1_MINFO_RT=$(STAGE1_MDIR)/tcljx.rt/module-info.class
$(STAGE1_MINFO_RT): $(TCLJX_SOURCE_RT)
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	mkdir -p --mode 700 "$(dir $@)"
	$(BUILD_JAVAC) -d "$(dir $@)" $^

STAGE1_MINFO_CORE=$(STAGE1_MDIR)/tcljx.core/module-info.class
$(STAGE1_MINFO_CORE): $(STAGE1_MINFO_RT) $(TCLJX_SOURCE_CORE) $(STAGE0_MDIR)/DONE
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	$(COMPILER_STAGE0) -d "$(dir $@)" -s src/tcljx.core clojure.core.all
	$(BUILD_JAVAC) -p $(STAGE1_MDIR) -d "$(dir $@)" src/tcljx.core/module-info.java

# diff -Nru src/tcljx.alpha ../tcljx.alpha.patched >alpha.patch
ALPHA_PATCHED=$(TMP_USER)/tcljx.alpha.patched
STAGE1_MINFO_ALPHA=$(STAGE1_MDIR)/tcljx.alpha/module-info.class
$(STAGE1_MINFO_ALPHA): $(STAGE1_MINFO_CORE) $(TCLJX_SOURCE_ALPHA) $(STAGE0_MDIR)/DONE alpha.patch
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	rm -rf "$(ALPHA_PATCHED)"
	cp -r src/tcljx.alpha "$(ALPHA_PATCHED)"
	patch -p2 -d "$(ALPHA_PATCHED)" <alpha.patch
	$(COMPILER_STAGE0) -d "$(dir $@)" -s $(dir $(STAGE1_MINFO_CORE)) -s "$(ALPHA_PATCHED)" tcljx.alpha.all
	$(BUILD_JAVAC) -p $(STAGE1_MDIR) -d "$(dir $@)" "$(ALPHA_PATCHED)"/module-info.java

# diff -Nru src/tcljx.compiler ../tcljx.compiler.patched >compiler.patch
COMPILER_PATCHED=$(TMP_USER)/tcljx.compiler.patched
STAGE1_MINFO_COMPILER=$(STAGE1_MDIR)/tcljx.compiler/module-info.class
$(STAGE1_MINFO_COMPILER): $(STAGE1_MINFO_ALPHA) $(TCLJX_SOURCE_COMPILER) compiler.patch
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	rm -rf "$(COMPILER_PATCHED)"
	cp -r src/tcljx.compiler "$(COMPILER_PATCHED)"
	patch -p2 -d "$(COMPILER_PATCHED)" <compiler.patch
	$(COMPILER_STAGE0) -d "$(dir $@)" -s $(dir $(STAGE1_MINFO_CORE)) -s $(dir $(STAGE1_MINFO_ALPHA)) -s "$(COMPILER_PATCHED)" $(TCLJX_MAIN_NS)
	$(BUILD_JAVAC) -p $(STAGE1_MDIR) -d "$(dir $@)" "$(COMPILER_PATCHED)"/module-info.java

$(STAGE1_MDIR)/tcljx.rtiow/ray.ppm: $(STAGE1_MINFO_CORE) $(TCLJX_SOURCE_RTIOW)
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	$(COMPILER_STAGE0) -d $(STAGE1_MDIR)/tcljx.rtiow -s $(STAGE1_MDIR)/tcljx.rt -s $(STAGE1_MDIR)/tcljx.core -s test/tcljx.compiler tcljx.nmspgen.rtiow-ref
	$(JAVA) -cp $(STAGE1_MDIR)/tcljx.rt:$(dir $<):$(STAGE1_MDIR)/tcljx.rtiow tcljx.nmspgen.rtiow-ref.___ >$@
	@echo "3cf6c9b9f93edb0de2bc24015c610d78  $@" | md5sum -c -

# ------------------------------------------------------------------------
# Use stage1 compiler to build modules for core library and compiler.
# Build the module directories in $(STAGE2_MDIR).(rt|core|compiler).

STAGE2_MDIR=$(TMP_USER)/tcljx-stage2.mdir-xpl
STAGE2_MDIR_JAR=$(TMP_USER)/tcljx-stage2.mdir-jar

STAGE2_MINFO_RT=$(STAGE2_MDIR)/tcljx.rt/module-info.class
$(STAGE2_MINFO_RT): $(STAGE1_MINFO_RT)
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	mkdir  -p --mode 700 $(STAGE2_MDIR)
	cp -r $(STAGE1_MDIR)/tcljx.rt $(STAGE2_MDIR)

STAGE2_MINFO_CORE=$(STAGE2_MDIR)/tcljx.core/module-info.class
$(STAGE2_MINFO_CORE): $(STAGE2_MINFO_RT) $(TCLJX_SOURCE_CORE) $(STAGE1_MINFO_COMPILER)
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	$(COMPILER_STAGE1) -d "$(dir $@)" -s src/tcljx.core clojure.core.all
	$(BUILD_JAVAC) -p $(STAGE2_MDIR) -d "$(dir $@)" src/tcljx.core/module-info.java
	diff -Nrq $(dir $(STAGE1_MINFO_CORE)) $(dir $@)

STAGE2_MINFO_ALPHA=$(STAGE2_MDIR)/tcljx.alpha/module-info.class
$(STAGE2_MINFO_ALPHA): $(STAGE2_MINFO_CORE) $(TCLJX_SOURCE_ALPHA) $(STAGE1_MINFO_COMPILER)
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	$(COMPILER_STAGE1) -d "$(dir $@)" -s $(dir $(STAGE2_MINFO_CORE)) -s "$(ALPHA_PATCHED)" tcljx.alpha.all
	$(BUILD_JAVAC) -p $(STAGE2_MDIR) -d "$(dir $@)" "$(ALPHA_PATCHED)"/module-info.java
	diff -Nrq $(dir $(STAGE1_MINFO_ALPHA)) $(dir $@)

STAGE2_MINFO_COMPILER=$(STAGE2_MDIR)/tcljx.compiler/module-info.class
$(STAGE2_MINFO_COMPILER): $(STAGE2_MINFO_ALPHA) $(TCLJX_SOURCE_COMPILER)
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	$(COMPILER_STAGE1) -d "$(dir $@)" -s $(dir $(STAGE2_MINFO_CORE)) -s $(dir $(STAGE2_MINFO_ALPHA)) -s "$(COMPILER_PATCHED)" $(TCLJX_MAIN_NS)
	$(BUILD_JAVAC) -p $(STAGE2_MDIR) -d "$(dir $@)" "$(COMPILER_PATCHED)"/module-info.java
	diff -Nrq $(dir $(STAGE1_MINFO_COMPILER)) $(dir $@)

$(STAGE2_MDIR_JAR)/DONE: $(STAGE2_MINFO_COMPILER)
	@echo; echo "### $(dir $@)"
	@rm -rf "$(dir $@)"
	$(BUILD_JAR) --create --file=$(dir $@)/tcljx-rt.jar -C "$(dir $(STAGE2_MINFO_RT))" .
	$(BUILD_JAR) --create --file=$(dir $@)/tcljx-core.jar -C "$(dir $(STAGE2_MINFO_CORE))" .
	$(BUILD_JAR) --create --file=$(dir $@)/tcljx-alpha.jar -C "$(dir $(STAGE2_MINFO_ALPHA))" .
	$(BUILD_JAR) --create --file=$(dir $@)/tcljx-compiler.jar --main-class=$(TCLJX_MAIN_NS).___ -C "$(dir $(STAGE2_MINFO_COMPILER))" .
	touch $@

##########################################################################

compile: support/DONE $(STAGE1_MINFO_RT)
	$(COMPILER_BOOT) -s src/tcljx.alpha -s src/tcljx.compiler -s test/tcljx.compiler $(RUN_TESTS_NS)
watch-and-compile: support/DONE $(STAGE1_MINFO_RT)
	$(COMPILER_BOOT) --watch -s src/tcljx.alpha -s src/tcljx.compiler -s test/tcljx.compiler $(RUN_TESTS_NS)


# Call with "make test TEST=<scope>" (with <scope> being "ns-name" or
# "ns-name/var-name") to only run tests from the given namespace or
# var.  Only call this after compile, possibly while one of the
# watch-and-xxx targets is running.
test: support/DONE $(STAGE1_MINFO_RT)
	$(JAVA) -p ../bootstrap-tcljc --add-modules tcljc.core -cp $(DEST_DIR) $(RUN_TESTS_NS).___
#	$(COMPILER_BOOT) -s src/tcljx.alpha -s src/tcljx.compiler -s test/tcljx.compiler $(RUN_TESTS_NS)/run
watch-and-test: support/DONE $(STAGE1_MINFO_RT)
	$(COMPILER_BOOT) --watch -s src/tcljx.alpha -s src/tcljx.compiler -s test/tcljx.compiler $(RUN_TESTS_NS)/run


stage0-mdir: $(STAGE0_MDIR)/DONE
stage1-rt: $(STAGE1_MINFO_RT)
stage1-core: $(STAGE1_MINFO_CORE)
stage1-alpha: $(STAGE1_MINFO_ALPHA)
stage1-compiler: $(STAGE1_MINFO_COMPILER)
stage1-rtiow: $(STAGE1_MDIR)/tcljx.rtiow/ray.ppm
stage2-rt: $(STAGE2_MINFO_RT)
stage2-core: $(STAGE2_MINFO_CORE)
stage2-alpha: $(STAGE2_MINFO_ALPHA)
stage2-compiler: $(STAGE2_MINFO_COMPILER)
bootstrap-and-check: stage2-compiler stage1-rtiow
bootstrap-mdir: bootstrap-and-check $(STAGE2_MDIR_JAR)/DONE

install-into-bootstrap-tcljx: bootstrap-mdir
	$(MAKE) -C ../bootstrap-tcljx pack JAR=$(BUILD_JAR)
	cp -f  $(STAGE2_MDIR_JAR)/*.jar ../bootstrap-tcljx
	$(MAKE) -C ../bootstrap-tcljx unpack JAR=$(BUILD_JAR)
