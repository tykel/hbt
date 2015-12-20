#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "crc.h"

#define MAX_TILES (32*32)

uint32_t tile_crc[MAX_TILES];
uint8_t tile_data[MAX_TILES][32];

void print_tile(uint8_t *);

void add_crc(uint8_t *tdata, int id)
{
    uint32_t crc = crc_init();
    crc = crc_update(crc, tdata, 32);
    crc = crc_finalize(crc);
    tile_crc[id] = crc;
}

int compare_tile(uint8_t* tdata, int id)
{
    uint32_t crc = crc_init();
    crc = crc_update(crc, tdata, 32);
    crc = crc_finalize(crc);
    //printf("against tile %d\n", id);
    //print_tile(tile_data[id]);
    return crc == tile_crc[id];
}

void flipx_tile(uint8_t* dst_tdata, uint8_t *src_tdata)
{
    int y;
    for(y = 0; y < 8; y++) {
        union {
            uint32_t dw;
            uint8_t b[4];
        } line, rline;
        line.dw = *(uint32_t *)&src_tdata[y*4];
        rline.b[0] = (line.b[3] >> 4) | ((line.b[3] & 0x0f)<<4);
        rline.b[1] = (line.b[2] >> 4) | ((line.b[2] & 0x0f)<<4);
        rline.b[2] = (line.b[1] >> 4) | ((line.b[1] & 0x0f)<<4);
        rline.b[3] = (line.b[0] >> 4) | ((line.b[0] & 0x0f)<<4);
        *(uint32_t *)&dst_tdata[y*4] = rline.dw;
    }
}

void flipy_tile(uint8_t* dst_tdata, uint8_t *src_tdata)
{
    int y;
    for(y = 0; y < 8; y++) {
        memcpy(dst_tdata + y*4, src_tdata + (7-y)*4, 4);
    }
}

void flipxy_tile(uint8_t* dst_tdata, uint8_t *src_tdata)
{
    int y;
    for(y = 0; y < 8; y++) {
        union {
            uint32_t dw;
            uint8_t b[4];
        } line, rline;
        line.dw = *(uint32_t *)&src_tdata[(7-y)*4];
        rline.b[0] = (line.b[3] >> 4) | ((line.b[3] & 0x0f)<<4);
        rline.b[1] = (line.b[2] >> 4) | ((line.b[2] & 0x0f)<<4);
        rline.b[2] = (line.b[1] >> 4) | ((line.b[1] & 0x0f)<<4);
        rline.b[3] = (line.b[0] >> 4) | ((line.b[0] & 0x0f)<<4);
        *(uint32_t *)&dst_tdata[y*4] = rline.dw;
    }
}

void print_tile(uint8_t *tdata)
{
    printf("%02x%02x%02x%02x\n", tdata[0], tdata[1], tdata[2], tdata[3]);
    printf("%02x%02x%02x%02x\n", tdata[4], tdata[5], tdata[6], tdata[7]);
    printf("%02x%02x%02x%02x\n", tdata[8], tdata[9], tdata[10], tdata[11]);
    printf("%02x%02x%02x%02x\n", tdata[12], tdata[13], tdata[14], tdata[15]);
    printf("%02x%02x%02x%02x\n", tdata[16], tdata[17], tdata[18], tdata[19]);
    printf("%02x%02x%02x%02x\n", tdata[20], tdata[21], tdata[22], tdata[23]);
    printf("%02x%02x%02x%02x\n", tdata[24], tdata[25], tdata[26], tdata[27]);
    printf("%02x%02x%02x%02x\n", tdata[28], tdata[29], tdata[30], tdata[31]);
}

int main(int argc, char *argv[])
{
    FILE *flvl = NULL;
    FILE *ftmap = NULL;
    uint8_t lvl[32768];
    char output_name[256];
    int x, y, t, i;
    int num_tiles = 0;
    
    if(argc < 2) {
        printf("error: no level data supplied...\n");
        printf("usage: tilemapper [level.bin]...\n");
        return 1;
    }
   
    for(i = 1; i < argc; i++) {
        if((flvl = fopen(argv[i], "rb")) == NULL) {
            printf("error: invalid level file supplied...\n");
            return 1;
        }
        fread(lvl, 1, 32768, flvl);
        fclose(flvl);

        for(y = 0; y < 32; y++) {
            for(x = 0; x < 32; x++) {
                uint8_t tile[32];
                int ty;
                for(ty = 0; ty < 8; ty++) {
                    memcpy(tile + ty*4, &lvl[((y*8)+ty)*128 + x*4], 4);
                }
                //printf("comparing:\n");
                //print_tile(tile);
                //printf("------\n");
                if(num_tiles > 0) {
                    int tid;
                    for(tid = 0; tid < num_tiles; tid++) {
                        uint8_t temp[32];
                        // Compare tile with all flip variations
                        if(compare_tile(tile, tid))
                            break;
                        //flipx_tile(temp, tile);
                        //printf("comparing flipx:\n");
                        //print_tile(temp);
                        //if(compare_tile(temp, tid))
                        //    break;
                        //flipy_tile(temp, tile);
                        //printf("comparing flipy:\n");
                        //print_tile(temp);
                        //if(compare_tile(temp, tid))
                        //    break;
                        //flipxy_tile(temp, tile);
                        //printf("comparing flipxy:\n");
                        //print_tile(temp);
                        //if(compare_tile(temp, tid))
                        //    break;
                    }
                    if(tid == num_tiles) {
                        memcpy(&tile_data[tid], tile, 32);
                        num_tiles += 1;
                        add_crc(tile_data[tid], tid);
                    } else {
                        //printf("--- match found\n");
                    }
                } else {
                    memcpy(tile_data, tile, 32);
                    num_tiles = 1;
                    add_crc(tile_data[0], 0);
                }
                //printf("--------------------\n");
            }
        }
    }

    snprintf(output_name, 256, "%s.tmap", "default");
    if((ftmap = fopen(output_name, "wb")) == NULL) {
        printf("error: could not write to %s\n", output_name);
        return 1;
    }
    for(t = 0; t < num_tiles; t++) {
        fwrite(tile_data[t], 32, 1, ftmap);
    }
    fclose(ftmap);
    printf("found a total of %d unique tiles, out of a total of %d\n",
            num_tiles, 32*32);
    printf("output written to %s\n", output_name);

    return 0;
}

