
# We create a .mlb project file in src/, which we pass to MLton
# primarily in order to get good error checking and reporting. The
# actual build just concats the source files to produce a single
# vext.sml file which can then be run from a script.

SOURCES	:= \
	src/version.sml \
	src/types.sml \
	src/filebits.sml \
	src/control.sml \
	src/sml-simplejson/json.sml \
	src/jsonbits.sml \
	src/provider.sml \
	src/hg.sml \
	src/git.sml \
	src/anycontrol.sml \
	src/archive.sml \
	src/app.sml

vext.sml:	$(SOURCES)
	echo '$$(SML_LIB)/basis/basis.mlb' > src/vext.mlb
	echo $(SOURCES) | sed 's,src/,,g' | fmt -1 >> src/vext.mlb
	echo "main.sml" >> src/vext.mlb
	mlton src/vext.mlb
	echo "(*" > $@
	echo "    DO NOT EDIT THIS FILE." >> $@
	echo "    This file is automatically generated from the individual" >> $@
	echo "    source files in the Vext repository." >> $@
	echo "*)" >> $@
	echo >> $@
	cat $(SOURCES) >> $@
	./vext version

.PHONY:	test
test:	vext.sml
	if ! ./test/run-tests.sh ; then ./test/run-tests.sh -v ; fi

.PHONY:	test-all
test-all:	vext.sml
	if ! ./test/run-all-tests.sh ; then ./test/run-all-tests.sh -v ; fi

clean:
	rm -f vext.sml src/vext.mlb src/vext

