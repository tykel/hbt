all: hbt.c16 tiler pal

hbt.c16: hbt.s data/1h.bin.map data/palette.bin gfx/c2b.bin gfx/enemy.bin gfx/stuffx.bin gfx/tiles.bin
	as16 $< -o $@ -m

CFLAGS=

tiler: tiler.c
	gcc -g $(CFLAGS) $< -o $@

pal: pal.c
	gcc -g $(CFLAGS) $< -o $@
