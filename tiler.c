#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#define TILE_W 4 
#define TILE_H 8
#define NTILES_W 32 
#define NTILES_H 32
#define TILESET_SIZE 93

int compare_tile(uint8_t *tile, uint8_t *level, int x, int y)
{
    int row;
    uint8_t buffer[32];
    for(row = 0; row < TILE_H; ++row) {
        memcpy(buffer + row*4, level + (y*8 + row)*128 + x*4, 4);
    }
   
    /* Check with no mirroring */
    for(row = 0; row < TILE_H; ++row) {
        uint32_t src = *(uint32_t *)(tile + row*4);
        uint32_t dst = *(uint32_t *)(buffer + row*4);
        if(src != dst) {
            return 0;
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
        //fprintf(stderr, "error: tilemap not big enough... (%d bytes)\n",
        //        tilemap_size);
        //exit(1);
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
                    //int solid = (t!=3 && t!=15 && t!=16 && t!=17 && t!=18 &&
                    //             t!=19 && t!=22 && t!=23 && t!=24 && t!=25 &&
                    //             t!= 26 && t!=27 && t!=28 && t!=30 && t!=11) 
                    //            << 6;
                    int solid = (t==1||t==2||t==3||t==4||t==5||t==6||t==7||t==8||t==12||t==14||t==15||t==16||t==17||t==35||t==36) << 6;
                    //int end = (t==15 || t==16 || t==18 || t==19) << 7;
                    int end = (t==31||t==32||t==33||t==34) << 7;
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
