JAVA_HOME ?= ~/local/jdk-classfile
TCLJC_MDIR ?= ../bootstrap-tcljc

JAVA_BIN=$(if $(JAVA_HOME),$(JAVA_HOME)/bin/,)
JAVA=$(JAVA_BIN)java
JAVAC=$(JAVA_BIN)javac
JAVAP=$(JAVA_BIN)javap

JAVA_OPTS=--enable-preview -p $(TCLJC_MDIR) --add-modules tinyclj.core
TCLJC_OPTS=$(JAVA_OPTS) -m tinyclj.compiler

MAIN_NS=tcljx.main
RUN_TESTS_NS=tcljx.run-tests

compile:
	$(JAVA) $(TCLJC_OPTS) $(RUN_TESTS_NS)
watch-and-compile:
	$(JAVA) $(TCLJC_OPTS) --watch $(RUN_TESTS_NS)

run:
	$(JAVA) $(TCLJC_OPTS) -d :none $(MAIN_NS)/run
watch-and-run:
	$(JAVA) $(TCLJC_OPTS) --watch $(MAIN_NS)/run


# $(DEST_DIR) matches the compiler's default destination directory
PROJECT_DIR ?= $(notdir $(PWD))
DEST_DIR=/tmp/$(USER)/tinyclj/$(PROJECT_DIR)

# Call with "make test TEST=<scope>" (with <scope> being "ns-name" or
# "ns-name/var-name") to only run tests from the given namespace or
# var.  Only call this after compile, possibly while one of the
# watch-and-xxx targets is running.
test:
	$(JAVA) $(JAVA_OPTS) -cp $(DEST_DIR) $(RUN_TESTS_NS).___
watch-and-test:
	$(JAVA) $(TCLJC_OPTS) --watch $(RUN_TESTS_NS)/run

clean:
	rm -rf "$(DEST_DIR)"/* "$(DEST_DIR)"*.* *.class hs_err_pid*.log replay_pid*.log

print-line-count:
	find src/tinyclj.compiler/tcljc -name "*.cljt" | xargs wc -l | sort -n

.PHONY: compile watch-and-compile test watch-and-test clean
