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

PLAYER_RUN   equ 0
PLAYER_JUMP  equ 1

DIR_LEFT     equ 0
DIR_RIGHT    equ 1

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
;-----------------------
; NEW    
;-----------------------
;    jz l_input_a_off
;    ldi r1, 1
;    jmp l_input_move
;-----------------------

    jz l_move
    ldm r2, v_gravity
    cmpi r2, 0
    jnz l_input_a_off
    ldm r2, v_grounded
    cmpi r2, 1
    jnz l_input_a_off
    ldi r1, 1
    jmp l_move
l_input_a_off:
    ldi r1, 0
;-----------------------
;l_input_move:
;    mov ra, r0
;    mov rb, r1
;    call l_move_player
;    mov rc, re              ; keep old player x for tile redrawing
;    mov rd, rf              ; likewise for old player y
;    jmp l_draw_missing
;-----------------------
    
l_move:
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
    subi ra, 2
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
    addi ra, 18             ; add 2 + 16 (size of sprite) 
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
    ldi r0, PLAYER_JUMP
    stm r0, v_state
    ldi r3, -12
    stm r3, v_gravity
l_move_up_grav:
    ldm r3, v_gravity
    mov ra, re              ; check for left part of sprite
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
    addi ra, 16             ; by adding size of player sprite
    divi ra, 8
    mov rb, rf
    cmpi r3, 0
    jl l_move_up_gravr
    addi rb, 16             ; add size of player sprite!
l_move_up_gravr:
    add rb, r3
    divi rb, 8
    call l_tile_solid
    tsti ra, 1
    jnz l_move_up_end       ; tile is solid, stop falling
    ldi r4, 0
    add rf, r3
    addi r3, 1
    cmpi r3, 8
    jl l_move_end
    ldi r3, 7               ; gravity of 7 pixels/frame max.
    jmp l_move_end
l_move_up_end:
    cmpi r3, 0
    jl l_move_up_end_ng     ; grounded if solid tile AND falling down
l_move_up_end_g:
    ldm r4, v_grounded_old
    cmpi r4, 1
    jz l_move_up_end_g2     ; skip playing sound if we were already grounded
    call l_sound_fall
l_move_up_end_g2:
    ldm r4, v_grounded
    stm r4, v_grounded_old  ; grounded_old = grounded
    ldi r4, 1
    stm r4, v_grounded      ; grounded = 1
    ldi r3, PLAYER_RUN
    stm r3, v_state         ; player is not falling, change sprite
    ldi r3, 0               ; reset the gravity
    jmp l_move_end
l_move_up_end_ng:
    ldi r4, 0
    stm r4, v_grounded
l_move_end:
    stm r3, v_gravity
    jmp l_draw_missing

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
    ldi r0, data_lvl
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

;------------------------------------------------------------------------------
; l_tile_solid: Routine returning whether a tile (x,y) is solid.
;
; input:  ra=x, rb=y
; output: ra=0,1
;------------------------------------------------------------------------------
l_tile_solid:
    push r0
    mov r0, rb
    muli r0, 32
    add r0, ra
    addi r0, data_lvl
    ldm r0, r0
    shr r0, 6
    andi r0, 1
    mov ra, r0
    pop r0
    ret

;------------------------------------------------------------------------------
; l_sound_fall: Routine to play the sound of the player landing on the ground.
; 
; It uses a short noise envelope at 2000 Hz to do so.
;------------------------------------------------------------------------------
l_sound_fall:
    sng 0x62, 0xa3a5
    ldi ra, v_snd_fall
    snp ra, 80
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

;------------------------------------------------------------------------------
; Move the player according to input, v-speed, and tilemap.
;
; input: ra=h-move [0=none, 1=left, 2=right], rb=jump
; output: none
;------------------------------------------------------------------------------
l_move_player:
    ldi r9, 8

l_move_player_h:
    mov r0, re
    mov r1, rf
    mov r2, ra
    push rb
    cmpi ra, 0
    jz l_move_player_v      ; no movement need on h-axis
l_move_player_h_l:
    cmpi ra, 1
    jnz l_move_player_h_r
    subi r0, 2
    jmp l_move_player_h_test
l_move_player_h_r:
    addi r0, 2
    addi r0, 16             ; add player width as we compare right side here
l_move_player_h_test:
    div r0, r9, ra
    div r1, r9, rb          ; get tile (x,y) of new position
    call l_tile_solid
    cmpi ra, 1
    jz l_move_player_v      ; solid tile at new position; don't move
    div r0, r9, ra
    div r1, r9, rb
    addi rb, 1              ; we now test the under tile (x,y) of new position
    call l_tile_solid
    cmpi ra, 1
    jz l_move_player_v      ; solid tile at new position; don't move
    cmpi r2, 2
    jl l_move_player_h_test2
    subi r0, 16
l_move_player_h_test2:
    mov re, r0              ; otherwise, update player x

l_move_player_v:
    pop rb
    cmpi rb, 1
    jnz l_move_player_v_update
    ldm r0, v_gravity
    cmpi r0, 0
    jnz l_move_player_v_update  ; jump if player is on ground, i.e. gravity==0
    ldi r2, -12 
    stm r2, v_gravity
    jmp l_move_player_v_l
l_move_player_v_update:
    ldm r2, v_gravity
    addi r2, 1
    cmpi r2, 8
    jl l_move_player_v_update_store
    ldi r2, 7               ; clamp downward v-speed to 7 pixels/frame
l_move_player_v_update_store:
    stm r2, v_gravity
l_move_player_v_l:
    mov r0, re
    mov r1, rf
    add r1, r2
    cmpi r2, 0
    jl l_move_player_v_l2
    addi r1, 16             ; add player height as we compare under side here
l_move_player_v_l2:
    div r0, r9, ra
    div r1, r9, rb          ; get tile (x,y) of new position
    call l_tile_solid
    cmpi ra, 1
    jz l_move_player_end    ; solid tile at new position; don't move
    cmpi r2, 0
    jl l_move_player_vl3
    subi r1, 16
l_move_player_vl3:
    mov rf, r1

l_move_player_v_r:
    mov r0, re
    addi r0, 16
    mov r1, rf
    add r1, r2
    cmpi r2, 0
    jl l_move_player_v_r2
    addi r1, 16
l_move_player_v_r2:
    div r0, r9, ra
    div r1, r9, rb
    cmpi ra, 1
    jz l_move_player_end
    cmpi r2, 0
    jl l_move_player_v_r3
    subi r1, 16
l_move_player_v_r3:
    mov rf, r1

l_move_player_end:
    ret

