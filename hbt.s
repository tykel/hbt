importbin ./data/palette.bin 0 48 data_pal
importbin ./gfx/c2b.bin 0 1664 spr_c2b
importbin ./gfx/enemy.bin 0 256 spr_enemy
importbin ./gfx/stuffx.bin 0 224 spr_stuffx
importbin ./gfx/tiles.bin 0 2976 spr_tiles
importbin ./data/1h.bin.map 0 1024 data_lvl1
importbin ./data/2a.bin.map 0 1024 data_lvl2
importbin ./data/3p.bin.map 0 1024 data_lvl2
importbin ./data/4p.bin.map 0 1024 data_lvl2
importbin ./data/5y.bin.map 0 1024 data_lvl2

io_pad1     equ 0xfff0
PAD_UP      equ 0x01
PAD_DOWN    equ 0x02
PAD_LEFT    equ 0x04
PAD_RIGHT   equ 0x08
PAD_SELECT  equ 0x10
PAD_START   equ 0x20
PAD_A       equ 0x40
PAD_B       equ 0x80

PLAYER_RUN  equ 0
PLAYER_JUMP equ 1

DIR_LEFT    equ 0
DIR_RIGHT   equ 1

LAST_LEVEL  equ 4

;------------------------------------------------------------------------------
; l_init: initialise global variables and drawing
;
; re: player x
; rf: player y
;------------------------------------------------------------------------------
l_init:
    pal data_pal
    bgc 0x1
    ldi re, 38 
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
    tsti r2, 0
    jnz l_input_left
    ldi r0, 0
    stm r0, v_running
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
    jnz l_input_a_checks
    ldi r3, 0
    stm r3, v_apress
    jmp l_move
l_input_a_checks:
    ldm r3, v_apress
    cmpi r3, 1
    jz l_move
    ldi r1, 1
    stm r1, v_apress
    
l_move:
    ldm r4, v_grounded
    stm r4, v_grounded_old  ; grounded_old = grounded

    mov rc, re              ; keep old player x for tile redrawing
    mov rd, rf              ; likewise for old player y
l_move_left:
    cmpi r0, 1
    jnz l_move_right
    ldi r3, DIR_LEFT
    stm r3, v_dir
    ldi r3, PLAYER_RUN
    stm r3, v_state
    mov ra, re
    addi ra, 2
    divi ra, 8              ; ra: tile x of 2 pixels left
    mov rb, rf
    divi rb, 8              ; rb: tile y
    call l_tile_solid
    tsti ra, 1
    jnz l_move_stop         ; tile is solid, don't move left
    subi re, 2
    ldm r3, v_running
    not r3
    andi r3, 1
    stm r3, v_running
    jmp l_move_up
l_move_right:
    cmpi r0, 2
    jnz l_move_up
    ldi r3, DIR_RIGHT
    stm r3, v_dir
    ldi r3, PLAYER_RUN
    stm r3, v_state
    mov ra, re
    addi ra, 12             ; add 2 + 16 (size of sprite) 
    divi ra, 8              ; ra: tile x of 2 pixels right
    mov rb, rf
    divi rb, 8              ; rb: tile y
    call l_tile_solid
    tsti ra, 1
    jnz l_move_stop         ; tile is solid, don't move right
    addi re, 2
    ldm r3, v_running
    not r3
    andi r3, 1
    stm r3, v_running
    jmp l_move_up
l_move_stop:
    ldi r3, 0
    stm r3, v_running
    ldi r3, PLAYER_RUN
    stm r3, v_state
l_move_up:
    cmpi r1, 1
    jnz l_move_up_grav
    ldm r4, v_grounded
    cmpi r4, 1
    jnz l_move_up_grav
    ldi r3, PLAYER_JUMP
    stm r3, v_state
    ldi r3, -12
    stm r3, v_gravity
l_move_up_grav:
    ldm r3, v_gravity
    mov ra, re              ; check for left part of sprite
    addi ra, 4
    divi ra, 8
    mov rb, rf
    cmpi r3, 0
    jl l_move_up_gravl
    addi rb, 16             ; add size of player sprite!
l_move_up_gravl:
    add rb, r3
    divi rb, 8
    call l_tile_solid
    tsti ra, 1
    jnz l_move_up_end       ; tile is solid, stop falling
    mov ra, re              ; now check right part of sprite
    addi ra, 10             ; by adding size of player sprite
    divi ra, 8
    mov rb, rf
    cmpi r3, 0
    jl l_move_up_gravr
    addi rb, 16             ; add size of player sprite!
l_move_up_gravr:
    add rb, r3
    divi rb, 8
    call l_tile_solid
    cmpi ra, 1
    jz l_move_up_end        ; tile is solid, stop falling
    add rf, r3
    addi r3, 1
    cmpi r3, 8
    jl l_move_zzz
    ldi r3, 7               ; gravity of 7 pixels/frame max.
l_move_zzz:
    ldi r4, 0
    stm r4, v_grounded
    jmp l_move_end
l_move_up_end:
    mov ra, re
    divi ra, 8
    mov rb, rf
    addi rb, 15
    divi rb, 8
    call l_tile_end
    cmpi ra, 1
    jz l_next_level
    mov ra, re
    divi ra, 8
    mov rb, rf
    addi rb, 17 
    divi rb, 8
    push ra
    push rb
    call l_tile_solid
    cmpi ra, 1
    pop rb
    pop ra
    jz l_move_up_end_g
    addi ra, 1
    call l_tile_solid
    cmpi ra, 1
    jnz l_move_up_end_ng
l_move_up_end_g:
    ldm r4, v_grounded_old
    cmpi r4, 1
    jz l_move_up_end_g2     ; skip playing sound if we were already grounded
    call l_sound_fall
l_move_up_end_g2:
    ldi r4, 1
    stm r4, v_grounded      ; grounded = 1
    ldi r3, PLAYER_RUN
    stm r3, v_state         ; player is not falling, change sprite
    ldi r3, 1               ; reset the gravity
    jmp l_move_end
l_move_up_end_ng:
    ldi r4, 0
    stm r4, v_grounded
    ldi r3, 1
l_move_end:
    stm r3, v_gravity
l_move_adjust:
    mov ra, re
    addi ra, 4
    divi ra, 8
    mov rb, rf
    addi rb, 7
    divi rb, 8
    call l_tile_solid
    cmpi ra, 1
    ;jnz l_draw_missing
    jnz l_move_adjust_notin_solid
l_move_adjust_in_solid:
    spr 0x0804
    ldi r4, 0
    drw r4, r4, _inlinespr
    jmp l_m_a
_inlinespr:
    db 0x55, 0x55, 0x55, 0x55
    db 0x55, 0x55, 0x55, 0x55
    db 0x55, 0x55, 0x55, 0x55
    db 0x55, 0x55, 0x55, 0x55
    db 0x55, 0x55, 0x55, 0x55
    db 0x55, 0x55, 0x55, 0x55
    db 0x55, 0x55, 0x55, 0x55
    db 0x55, 0x55, 0x55, 0x55
l_move_adjust_notin_solid:
    spr 0x0804
    ldi r4, 0
    drw r4, r4, _inlinespr2
    jmp l_draw_missing
_inlinespr2:
    db 0x33, 0x33, 0x33, 0x33
    db 0x33, 0x33, 0x33, 0x33
    db 0x33, 0x33, 0x33, 0x33
    db 0x33, 0x33, 0x33, 0x33
    db 0x33, 0x33, 0x33, 0x33
    db 0x33, 0x33, 0x33, 0x33
    db 0x33, 0x33, 0x33, 0x33
    db 0x33, 0x33, 0x33, 0x33
l_m_a:
    cmpi r0, 1
    jnz l_move_adjustr
    addi re, 2
    jmp l_draw_missing
l_move_adjustr:
    cmpi r0, 2
    jnz l_draw_missing
    subi re, 2

;------------------------------------------------------------------------------
; l_draw_missing: Determine and redraw the tiles behind the player
;
; r0: Level data base
; r1: leftmost tile x
; r2: rightmost tile x
; r3: upmost tile y
; r4: downmost tile y
; r5: tile sprites base
; r6: screen ; r7: screen y
; r7: screen y
;------------------------------------------------------------------------------
l_draw_missing:
    spr 0x0804
    ldm r0, v_level
    shl r0, 10          ; 1024 bytes in a level
    addi r0, data_lvl1
    ldi r5, spr_tiles
    mov r1, rc
    divi r1, 8          ; r1: leftmost tile x
    mov r2, rc
    addi r2, 16
    divi r2, 8          ; r2: rightmost tile x
    mov r3, rd
    subi r3, 8
    divi r3, 8          ; r3: upmost tile y
    mov r4, rd
    addi r4, 24
    divi r4, 8          ; r4: downmost tile y
    mov r8, r1          ; save the leftmost tile x since we overwrite it below
l_draw_missing_loop_y:
    cmp r3, r4
    jg l_draw_missing_end
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
zzz_drw:
    drw r6, r7, r9

    addi r1, 1
    jmp l_draw_missing_loop_x
l_draw_missing_loop_y2:
    addi r3, 1
    jmp l_draw_missing_loop_y
l_draw_missing_end:
    spr 0x1008
    ldi r1, spr_c2b
    ldm r0, v_state
    cmpi r0, PLAYER_JUMP
    jnz l_draw_missing_run
    addi r1, 256
    ldm r0, v_gravity
    cmpi r0, 0
    jle l_draw_missing_dir
    addi r1, 128
    jmp l_draw_missing_dir
l_draw_missing_run:
    ldm r0, v_running
    cmpi r0, 1
    jnz l_draw_missing_dir
    ldm r0, v_counter
    addi r0, 1
    modi r0, 12
    stm r0, v_counter
    cmpi r0, 6 
    jl l_draw_missing_dir
    addi r1, 128
l_draw_missing_dir:
    ldm r0, v_dir
    cmpi r0, 0 
    jnz l_draw_missing_drw
    flip 1, 0
l_draw_missing_drw:
    drw re, rf, r1              ; draw the player in his new position
    flip 0, 0
    vblnk
    jmp l_input
    
l_next_level:
    ldm r0, v_level
    cmpi r0, LAST_LEVEL
    jz l_draw_missing
    call l_store_pal
    ldi r0, 0
l_next_level_loop:
    cmpi r0, 20
    jge l_next_level_end
    push r0
    call l_shade_pal
    call l_draw
    vblnk
    pop r0
    addi r0, 1
    jmp l_next_level_loop
l_next_level_end:
    call l_restore_pal
    ldm r0, v_level
    addi r0, 1
    stm r0, v_level
    jmp l_init

;------------------------
; store_pal: save the palette to 0xf000
;------------------------
l_store_pal:
    push r0
    push r1
    push r2
    push r3
    ldi r0, 0
    ldi r1, data_pal
    ldi r2, 0xf000          ; pick this address to store temp palette
l_store_pal_loop:
    cmpi r0, 48             ; 48 bytes of palette data
    jz l_store_pal_loop_end
    ldm r3, r1
    stm r3, r2
    addi r0, 2
    addi r1, 2
    addi r2, 2
    jmp l_store_pal_loop
l_store_pal_loop_end:
    pop r3
    pop r2
    pop r1
    pop r0
    ret

;------------------------
; restore_pal: load the palette from 0xf000
;------------------------
l_restore_pal:
    push r0
    push r1
    push r2
    push r3
    ldi r0, 0
    ldi r1, data_pal
    ldi r2, 0xf000          ; pick this address to store temp palette
l_restore_pal_loop:
    cmpi r0, 48             ; 48 bytes of palette data
    jz l_restore_pal_loop_end
    ldm r3, r2
    stm r3, r1
    addi r0, 2
    addi r1, 2
    addi r2, 2
    jmp l_restore_pal_loop
l_restore_pal_loop_end:
    pop r3
    pop r2
    pop r1
    pop r0
    ret

;------------------------
; shade_pal: divide each color component of the palette by 2
;------------------------
l_shade_pal:
    push r0
    push r1
    push r2
    push r3
    ldi r0, 0
    ldi r1, data_pal
l_shade_pal_loop:
    cmpi r0, 48             ; 48 bytes of palette data
    jz l_shade_pal_loop_end
    ldm r2, r1
    mov r3, r2
    andi r3, 0xff00
    andi r2, 0x00ff
    muli r2, 6
    divi r2, 7
    or r2, r3
    stm r2, r1
    addi r0, 1
    addi r1, 1
    jmp l_shade_pal_loop
l_shade_pal_loop_end:
    pop r3
    pop r2
    pop r1
    pop r0
    pal data_pal
    ret

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
    ldm r0, v_level
    shl r0, 10
    addi r0, data_lvl1
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
    push r1
    mov r0, rb
    muli r0, 32
    add r0, ra
    ldm r1, v_level
    shl r1, 10
    addi r1, data_lvl1
    add r0, r1
    ldm r0, r0
    andi r0, 0x3f
    muli r0, 32
    addi r0, spr_tiles
    mov ra, r0
    pop r1
    pop r0
    ret

;------------------------------------------------------------------------------
; l_tile_solid: Routine returning whether a tile (x,y) is solid.
;
; input:  ra=x, rb=y
; output: ra=0,1
;------------------------------------------------------------------------------
l_tile_solid:
    push r0
    push r1
    mov r0, rb
    muli r0, 32
    add r0, ra
    ldm r1, v_level
    shl r1, 10
    addi r1, data_lvl1
    add r0, r1
    ldm r0, r0
    shr r0, 6
    andi r0, 1
    mov ra, r0
    pop r1
    pop r0
    ret

;------------------------------------------------------------------------------
; l_tile_end: Routine returning whether a tile (x,y) is an exit tile.
;
; input:  ra=x, rb=y
; output: ra=0,1
;------------------------------------------------------------------------------
l_tile_end:
    push r0
    push r1
    mov r0, rb
    muli r0, 32
    add r0, ra
    ldm r1, v_level
    shl r1, 10
    addi r1, data_lvl1
    add r0, r1
    ldm r0, r0
    shr r0, 7
    andi r0, 1
    mov ra, r0
    pop r1
    pop r0
    ret

;------------------------------------------------------------------------------
; l_sound_fall: Routine to play the sound of the player landing on the ground.
; 
; It uses a short noise envelope at 2000 Hz to do so.
;------------------------------------------------------------------------------
l_sound_fall:
    sng 0x02, 0xa3a4
    ldi ra, v_snd_fall
    snp ra, 30
    ret

;------------------------------------------------------------------------------
; Variables stored in RAM.
;------------------------------------------------------------------------------
v_running:
    dw 0
v_gravity:
    dw 0
v_grounded:
    dw 0
v_grounded_old:
    dw 0
v_state:
    dw 0
v_dir:
    dw 0
v_frame:
    dw 0
v_counter:
    dw 0
v_snd_fall:
    dw 2000
v_apress:
    dw 0
v_level:
    dw 0
