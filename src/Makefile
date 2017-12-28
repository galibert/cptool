TARGET= cptool
LUAINC= 
LUALIB= -llua

DEPLIB= 

OBJS = ltype.o cptool.o parse.o
SRCS = ltype.cc cptool.cc parse.cc
HDRS = ltype.h parse.h
JUNK =

OPT=-O9
CFLAGS= ${LUAINC}
CXX=c++
CXXFLAGS= ${OPT} -std=c++17 -g3 -Wall
LIBS= ${OPT} -g3 ${LUALIB}

${TARGET} : ${OBJS} ${DEPLIB} Makefile
	${CXX} -o $@ ${OBJS} ${LIBS}

clean:
	rm -f ${OBJS} ${TARGET}
###
ltype.o: ltype.h
cptool.o: parse.h ltype.h
parse.o: parse.h ltype.h
