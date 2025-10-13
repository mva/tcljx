JAVA_HOME ?= ~/local/jdk-classfile
TCLJC_MDIR ?= ../bootstrap-tcljc

JAVA_BIN=$(if $(JAVA_HOME),$(JAVA_HOME)/bin/,)
JAVA=$(JAVA_BIN)java
JAVAC=$(JAVA_BIN)javac
JAVAP=$(JAVA_BIN)javap

# Note: only textflow__terminal requires --enable-native-access
JAVA_OPTS=-p $(TCLJC_MDIR) --add-modules tcljc.core --enable-native-access=ALL-UNNAMED
TCLJC_OPTS=$(JAVA_OPTS) -m tcljc.compiler

#MAIN_NS=tcljx.alpha.textflow__terminal
MAIN_NS=tcljx.main
RUN_TESTS_NS=tcljx.run-tests

compile:
	$(JAVA) $(TCLJC_OPTS) $(MAIN_NS) $(RUN_TESTS_NS)
watch-and-compile:
	$(JAVA) $(TCLJC_OPTS) --watch $(MAIN_NS) $(RUN_TESTS_NS)

run:
	$(JAVA) $(TCLJC_OPTS) -d :none $(MAIN_NS)/run
watch-and-run:
	$(JAVA) $(TCLJC_OPTS) --watch $(MAIN_NS)/run


# $(DEST_DIR) matches the compiler's default destination directory
PROJECT_DIR ?= $(notdir $(PWD))
DEST_DIR=/tmp/$(USER)/tcljc/$(PROJECT_DIR)

run-main:
	$(JAVA) $(JAVA_OPTS) -cp $(DEST_DIR) $(MAIN_NS).___ $(ARGS)

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
test:
# This variant is for the compiler's unit tests.  It avoids a single
# shared tcljc.rt/tinyclj.lang.RT whose markCoreInitialization() is
# first called from tcljc.core/tinyclj.core._10.<clinit> and then
# again in the running tests from tclj-dyn//tinyclj.core._10.<clinit>
	$(JAVA) -cp ../bootstrap-tcljc/tcljc.rt:../bootstrap-tcljc/tcljc.core:$(DEST_DIR) $(RUN_TESTS_NS).___
# This variant works for regular applications:
#	$(JAVA) $(JAVA_OPTS) -cp $(DEST_DIR) $(RUN_TESTS_NS).___
watch-and-test:
	$(JAVA) $(TCLJC_OPTS) --watch $(RUN_TESTS_NS)/run

clean:
	rm -rf "$(DEST_DIR)"/* "$(DEST_DIR)"*.* *.class textflow__termios.out hs_err_pid*.log replay_pid*.log

print-line-count:
	find src/tcljx -name "*.cljt" | grep -v src/tcljx/alpha/ | xargs wc -l | sort -n

print-lines-of-code:
	find src/tcljx -name "*.cljt" | grep -v src/tcljx/alpha/ | xargs grep -v '^ *\($$\|;\)' | wc -l

.PHONY: compile watch-and-compile test watch-and-test clean



textflow__termios.out: src/tcljx/alpha/textflow__termios.c
	gcc -Wall -o $@ $^

src/tcljx/alpha/textflow__termios.cljt: textflow__termios.out
	./$^ >$@
