importbin ./data/palette.bin 0 48 data_pal
importbin ./gfx/c2b.bin 0 1664 spr_c2b
importbin ./gfx/enemy.bin 0 256 spr_enemy
importbin ./gfx/stuffx.bin 0 224 spr_stuffx
importbin ./gfx/tiles.bin 0 992 spr_tiles
importbin ./data/1h.bin.map 0 1024 data_lvl

io_pad1     equ 0xfff0
PAD_UP      equ 0x01
PAD_DOWN    equ 0x02
PAD_LEFT    equ 0x04
PAD_RIGHT   equ 0x08
PAD_SELECT  equ 0x10
PAD_START   equ 0x20
PAD_A       equ 0x40
PAD_B       equ 0x80

;------------------------------------------------------------------------------
; l_init: initialise global variables and drawing
;
; re: player x
; rf: player y
;------------------------------------------------------------------------------
l_init:
    pal data_pal
    bgc 0x1
    ldi re, 24 
    ldi rf, 70 
    call l_draw
    jmp l_input

;------------------------------------------------------------------------------
; l_input: read controller input, and move the player
;
; r0: horizontal movement
; r1: jump?
; r2: controller status
;
; TODO: Perform collision checking with level, gravity
;------------------------------------------------------------------------------
l_input:
    ldi r0, 0
    ldi r1, 0
    ldm r2, io_pad1
l_input_left:
    tsti r2, PAD_LEFT
    jz l_input_right
    ldi r0, 1
l_input_right:
    tsti r2, PAD_RIGHT
    jz l_input_a
    ldi r0, 2
l_input_a:
    tsti r2, PAD_A
    jz l_move
    ldi r1, 1
l_move:
    mov rc, re
    mov rd, rf
l_move_left:
    cmpi r0, 1
    jnz l_move_right
    mov ra, re
    subi ra, 2
    divi ra, 8              ; ra: tile x of 2 pixels left
    mov rb, rf
    divi rb, 8              ; rb: tile y
    call l_tile_solid
    tsti ra, 1
    jnz l_move_up           ; tile is solid, don't move left
    subi re, 2
    jmp l_move_up
l_move_right:
    cmpi r0, 2
    jnz l_move_up
    mov ra, re
    addi ra, 2
    divi ra, 8              ; ra: tile x of 2 pixels right
    mov rb, rf
    divi rb, 8              ; rb: tile y
    call l_tile_solid
    tsti ra, 1
    jnz l_move_up           ; tile is solid, don't move right
    addi re, 2
l_move_up:
    ldm r3, v_gravity
    mov ra, re
    divi ra, 8
    mov rb, rf
    add rb, r3
    divi rb, 8
    call l_tile_solid
    tsti ra, 1
    jnz l_move_up_end       ; tile is solid, stop falling
    add rf, r3
    addi r3, 1
    jmp l_move_end
l_move_up_end:
    ldi r3, 0               ; reset the gravity
l_move_end:
    stm r3, v_gravity

;------------------------------------------------------------------------------
; l_draw_missing: Determine and redraw the tiles behind the player
;
; r0: Level data base
; r1: leftmost tile x
; r2: rightmost tile x
; r3: upmost tile y
; r4: downmost tile y
; r5: tile sprites base
; r6: screen x
; r7: screen y
;------------------------------------------------------------------------------
l_draw_missing:
    spr 0x0804
    ldi r0, data_lvl
    ldi r5, spr_tiles
    mov r1, rc
    divi r1, 8          ; r1: leftmost tile x
    mov r2, rc
    addi r2, 16
    divi r2, 8          ; r2: rightmost tile x
    mov r3, rd
    divi r3, 8          ; r3: upmost tile y
    mov r4, rd
    addi r4, 16
    divi r4, 8          ; r4: downmost tile y
    mov r8, r1          ; save the leftmost tile x since we overwrite it below
l_draw_missing_loop_y:
    cmp r3, r4
    jz l_draw_missing_end
    mov r1, r8
l_draw_missing_loop_x:
    cmp r1, r2
    jg l_draw_missing_loop_y2

    mov r6, r1
    muli r6, 8
    mov r7, r3
    muli r7, 8
    mov r9, r3
    muli r9, 32
    add r9, r1
    add r9, r0
    ldm r9, r9
    andi r9, 0x3f
    muli r9, 32
    add r9, r5
    drw r6, r7, r9

    addi r1, 1
    jmp l_draw_missing_loop_x
l_draw_missing_loop_y2:
    addi r3, 1
    jmp l_draw_missing_loop_y
l_draw_missing_end:
    spr 0x1008
    drw re, rf, spr_c2b         ; draw the player in his new position
    vblnk
    jmp l_input
    
;------------------------------------------------------------------------------
; l_draw: Level draw routine
;
; r0: level date base
; r1: tile x
; r2: tile y
; r3: scratch tile pointer
; r4: tile sprites base
; r6: screen x
; r7: screen y
;------------------------------------------------------------------------------
l_draw:
    cls
    spr 0x0804
    ldi r0, data_lvl
    ldi r4, spr_tiles
    ldi r2, 0
l_draw_lvly:
    ldi r1, 0
l_draw_lvlx:
    mov r3, r2
    muli r3, 32         ; 32 tiles in a row 
    add r3, r1
    add r3, r0
    ldm r3, r3
    andi r3, 0x3f       ; r3: tile ID
    mov r5, r3
    muli r5, 32         ; 8*4 = 32 bytes per tile
    add r5, r4          ; r5: ptr to tile sprite
    mov r6, r1
    muli r6, 8          ; r6: screen x
    mov r7, r2
    muli r7, 8          ; r7: screen y
    drw r6, r7, r5
    addi r1, 1
    cmpi r1, 32
    jl l_draw_lvlx
    addi r2, 1
    cmpi r2, 30
    jl l_draw_lvly
l_draw_end:
    vblnk
    ret

;------------------------------------------------------------------------------
; l_tile_ptr_from_xy: Routine to get a tile pointer from a tile (x,y) pair.
;
; input:  ra=x, rb=y
; output: ra=ptr
;------------------------------------------------------------------------------
l_tile_ptr_from_xy:
    push r0
    mov r0, rb
    muli r0, 32
    add r0, ra
    addi r0, data_lvl 
    ldm r0, r0
    andi r0, 0x3f
    muli r0, 32
    addi r0, spr_tiles
    mov ra, r0
    pop r0
    ret

l_tile_solid:
    push r0
    mov r0, rb
    muli r0, 32
    add r0, ra
    addi r0, data_lvl
    ldm r0, r0
    shl r0, 6
    andi r0, 1
    mov r0, ra
    pop r0
    ret

v_gravity:
    dw 0
