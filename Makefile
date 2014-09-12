#################################################################################
#                Ojs-filetree                                                   #
#                                                                               #
#    Copyright (C) 2014 INRIA. All rights reserved.                             #
#                                                                               #
#    This program is free software; you can redistribute it and/or modify       #
#    it under the terms of the GNU General Public License as                    #
#    published by the Free Software Foundation, version 3 of the License.       #
#                                                                               #
#    This program is distributed in the hope that it will be useful,            #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of             #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the               #
#    GNU Library General Public License for more details.                       #
#                                                                               #
#    You should have received a copy of the GNU General Public                  #
#    License along with this program; if not, write to the Free Software        #
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA                   #
#    02111-1307  USA                                                            #
#                                                                               #
#    As a special exception, you have permission to link this program           #
#    with the OCaml compiler and distribute executables, as long as you         #
#    follow the requirements of the GNU GPL in regard to all of the             #
#    software in the executable aside from the OCaml compiler.                  #
#                                                                               #
#    Contact: Maxence.Guesdon@inria.fr                                          #
#                                                                               #
#################################################################################

include master.Makefile

P=#p -p
PBYTE=#p -p a

OF_FLAGS=-package $(PACKAGES)

COMPFLAGS=-I +ocamldoc -annot -g -thread -verbose #-w +K
OCAMLPP=

RM=rm -f
CP=cp -f
MKDIR=mkdir -p

LIB=ojs-filetree.cmxa
LIB_A=$(LIB:.cmxa=.a)
LIB_CMXS=$(LIB:.cmxs)
LIB_BYTE=$(LIB:.cmxa=.cma)

LIB_CMXFILES=ojsft_types.cmx \
	ojsft_find.cmx \
	ojsft_files.cmx \
	ojsft_server.cmx

LIB_CMOFILES=$(LIB_CMXFILES:.cmx=.cmo)
LIB_CMIFILES=$(LIB_CMXFILES:.cmx=.cmi)
LIB_OFILES=$(LIB_CMXFILES:.cmx=.o)

LIBJS=ojs-filetree-js.cma

LIBJS_CMOFILES=ojsft_types.cmo \
	ojsft_js.cmo

LIBJS_CMIFILES=$(LIBJS_CMOFILES:.cmx=.cmi)


all: opt byte

opt: $(LIB) $(LIB_CMXS)

byte: $(LIB_BYTE) $(LIBJS)

$(LIB): $(LIB_CMIFILES) $(LIB_CMXFILES)
	$(OCAMLFIND) ocamlopt$(P) -a -o $@ $(LIB_CMXFILES)

$(LIB_CMXS): $(LIB_CMIFILES) $(LIB_CMXFILES)
	$(OCAMLFIND) ocamlopt$(P) -shared -o $@ $(LIB_CMXFILES)

$(LIB_BYTE): $(LIB_CMIFILES) $(LIB_CMOFILES)
	$(OCAMLFIND) ocamlc$(PBYTE) -a -o $@ $(LIB_CMOFILES)

$(LIBJS): $(LIBJS_CMIFILES) $(LIBJS_CMOFILES)
	$(OCAMLFIND) ocamlc$(PBYTE) -a -o $@ $(LIBJS_CMOFILES)

.PHONY: example
example: example-server example.js

example-server: $(LIB) example.cmx
	$(OCAMLFIND) ocamlopt -o $@ $(OF_FLAGS) -linkpkg $^
example.js: $(LIBJS) example_js.cmo
	$(OCAMLFIND) ocamlc -o t.x $^ -package yojson,js_of_ocaml -linkpkg
	$(JS_OF_OCAML) t.x -o $@

##########
.PHONY: doc webdoc ocamldoc

doc:
	$(OCAMLFIND) ocamldoc -d ocamldoc -html $(OF_FLAGS) -verbose  ojsft_*.ml

##########
install: install-lib

install-lib:
	@$(OCAMLFIND) install $(PACKAGE) META \
		$(LIB_CMIFILES) $(LIB_CMXFILES) $(LIB_OFILES) \
		$(LIB_BYTE) $(LIB) $(LIB_A) $(LIB_CMXS) \
		$(LIBJS)$(LIBJS_CMIFILES)

uninstall: uninstall-lib

uninstall-lib:
	@$(OCAMLFIND) remove $(PACKAGE)

#####
clean:
	$(RM) *.cm* *.o *.a *.x *.annot

distclean: clean
	$(RM) master.Makefile META
	$(RM) -fr config.status autom4te.cache config.log ocaml_config.sh

# archive :
###########
archive:
	git archive --prefix=$(PACKAGE)-$(VERSION)/ HEAD | gzip > ../ojs-filetree-pages/$(PACKAGE)-$(VERSION).tar.gz

# headers :
###########
HEADFILES= Makefile *.ml *.mli configure configure.ac
headers:
	echo $(HEADFILES)
	headache -h header -c .headache_config `ls $(HEADFILES) | grep -v plugin_example`

noheaders:
	headache -r -c .headache_config `ls $(HEADFILES)`

# myself :
##########
master.Makefile: master.Makefile.in config.status \
	META.in
	./config.status

config.status: configure
	./config.status --recheck

configure: configure.ac
	autoconf

#############
.PRECIOUS:

.PHONY: clean depend

.depend depend:
	$(OCAMLFIND) ocamldep `ls ojs*.ml ojs*.mli | grep -v js.ml`  > .depend

include .depend

############

