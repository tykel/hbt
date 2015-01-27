all: hbt.c16 tiler

hbt.c16: hbt.s
	as16 $^ -o $@ -m

CFLAGS=$(shell sdl2-config --cflags)
LIBS=$(shell sdl2-config --libs) 

tiler: tiler.c
	gcc -g $(CFLAGS) $^ -o $@ $(LIBS)
