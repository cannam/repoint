
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
	src/app.sml

default:	test

vext.sml:	$(SOURCES)
	echo '$$(SML_LIB)/basis/basis.mlb' > src/vext.mlb
	echo $(SOURCES) | sed 's,src/,,g' | fmt -1 >> src/vext.mlb
	echo "main.sml" >> src/vext.mlb
	mlton src/vext.mlb
	echo "(* This file is automatically generated from the individual " > $@
	echo "   source files in the Vext repository. *)" >> $@
	echo >> $@
	cat $(SOURCES) >> $@
	./vext version

test:	vext.sml
	cd test && ./test.sh

clean:
	rm -f vext.sml src/vext.mlb src/vext

