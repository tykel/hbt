#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

#define TILE_W 4 
#define TILE_H 8
#define NTILES_W 32 
#define NTILES_H 32
#define TILESET_SIZE 31

int compare_tile(uint8_t *tile, uint8_t *level, int x, int y)
{
    int row;
   
    /* Check with no mirroring */
    for(row = 0; row < TILE_H; ++row) {
        int col;
        uint8_t *tile2 = level + (y*TILE_H + row)*(TILE_W*NTILES_W) + x*TILE_W;
        for(col = 0; col < TILE_W; ++col) {
            //printf("checking pixel (%d, %d)\n", col, row);
            if(*tile2 != *(tile + row*TILE_W + col))
                goto flip_h;
            ++tile2;
        }
    }
    return 1;

flip_h:
    /* Check with horizontal mirroring */
    for(row = 0; row < TILE_H; ++row) {
        int col;
        uint8_t *tile2 = level + (y*TILE_H + row)*(TILE_W*NTILES_W) + x*TILE_W + TILE_W;
        for(col = 0; col < TILE_W; ++col) {
            //printf("checking pixel (%d, %d)\n", col, row);
            if((*tile2 & 0x0f) != (*(tile + row*TILE_W + col)) >> 8 ||
               (*tile2 >> 8) != (*(tile + row*TILE_W + col)) & 0x0f)
                return 0;
            --tile2;
        }
    }

    return 1;
}

int main(int argc, char *argv[])
{
    FILE *flevel, *ftilemap, *foutput;
    size_t tilemap_size, level_size;
    uint8_t *tilemap, *level, *output;
    int x, y, t;
    char output_name[256];
    
    if(argc < 2) {
        fprintf(stderr, "error: must supply tilemap...\n");
        exit(1);
    }

    ftilemap = fopen(argv[1], "rb");
    fseek(ftilemap, 0, SEEK_END);
    tilemap_size = ftell(ftilemap);
    fseek(ftilemap, 0, SEEK_SET);
    tilemap = malloc(tilemap_size);
    fread(tilemap, 1, tilemap_size, ftilemap);
    fclose(ftilemap);

    if(tilemap_size < TILE_W * TILE_H * TILESET_SIZE) {
        fprintf(stderr, "error: tilemap not big enough... (%d bytes)\n",
                tilemap_size);
        exit(1);
    }

    flevel = fopen(argv[2], "rb");
    fseek(flevel, 0, SEEK_END);
    level_size = ftell(flevel);
    fseek(flevel, 0, SEEK_SET);
    level = malloc(level_size);
    fread(level, 1, level_size, flevel);
    fclose(flevel);

    if(level_size < NTILES_W * NTILES_H * TILE_W * TILE_H) {
        fprintf(stderr, "error: level not big enough...\n");
        exit(1);
    }

    sprintf(output_name, "%s.map", argv[2]);
    foutput = fopen(output_name, "wb");
    output = malloc(NTILES_W * NTILES_H);

    for(y = 0; y < NTILES_H; ++y) {
        for(x = 0; x < NTILES_W; ++x) {
            //printf("checking tile (%d, %d)\n", x, y);
            for(t = 0; t < TILESET_SIZE; ++t) {
                //printf("checking against tilemap[%d]\n", t);
                if(compare_tile(tilemap + t*TILE_W*TILE_H,
                                level, x, y)) {
                    //printf("match found, tile[%d,%d] = tilemap[%d]\n", x, y, t);
                    int solid = (t!=3 && t!=15 && t!=16 && t!=17 && t!=18 &&
                                 t!=19 && t!=22 && t!=23 && t!=27 && t!=28 &&
                                 t!=30) 
                                << 6;
                    int end = (t==15 || t==16 || t==18 || t==19) << 7;
                    output[y*NTILES_W + x] = end | solid | t;
                    break;
                }
            }
            if(t == TILESET_SIZE) {
                fprintf(stderr, "error: no matching tile found at (%d,%d)\n",
                        x, y);
                return 1;
            }
        }
    }

    fwrite(output, NTILES_W*NTILES_H, 1, foutput);
    fclose(foutput);

    printf("wrote %d bytes to %s\n", NTILES_W*NTILES_H, output_name);

    return 0;
}
