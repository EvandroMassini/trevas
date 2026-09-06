; TREVAS / O GUARDIAO - original ZX Spectrum 48K / TK95 game
; Z80 assembly, Pasmo syntax. Entry point 32768, no ROM dependencies.
; Assets are sparse OR spans in a linear offscreen bitmap.
; Memory: 8000-DFFF code/art; E000 bitmap; F200 BFS; F300 queue;
; F400 map; F500 explored; FC00-FCFF stack; FDFD IM2 jump; FE00 table.
 org 32768
BUFFER equ 57344
DIST equ 61952
QUEUE equ 62208
MAP equ 62464
SEEN equ 62720

start:
 di
 ld sp,64768
 xor a
 out (254),a
 ld (clock),a
 ld hl,65024
 ld de,65025
 ld bc,256
 ld (hl),253
 ldir
 ld a,195
 ld (65021),a
 ld hl,irq
 ld (65022),hl
 ld a,254
 ld i,a
 im 2
 ei
 call clear_screen
 ld hl,title
 ld b,2
 ld c,3
 call text
 ld hl,subtitle
 ld b,4
 ld c,5
 call text
 ld hl,intro1
 ld b,9
 ld c,1
 call text
 ld hl,intro2
 ld b,11
 ld c,1
 call text
 ld hl,intro3
 ld b,13
 ld c,1
 call text
 ld hl,intro4
 ld b,16
 ld c,1
 call text
 ld hl,intro5
 ld b,18
 ld c,1
 call text
 ld hl,intro6
 ld b,22
 ld c,4
 call text
 call wait_space
new_game:
 ld a,(clock)
choose_maze:
 cp 3
 jr c,chosen
 sub 3
 jr choose_maze
chosen:
 ld (maze_id),a
 ld hl,maze_table
 call table_word
 ld de,MAP
 ld bc,256
 ldir
 ld a,(maze_id)
 ld e,a
 ld d,0
 ld hl,spawn_table
 add hl,de
 ld a,(hl)
 ld (monster),a
 ld hl,SEEN
 ld de,SEEN+1
 ld bc,255
 ld (hl),0
 ldir
 xor a
 ld (seals),a
 ld (map_mode),a
 ld (game_over),a
 ld (last_key),a
 ld (stun),a
 ld a,17
 ld (player),a
 ld a,1
 ld (direction),a
 ld (dirty),a
 ld a,2
 ld (charges),a
 ld a,200
 ld (enemy_timer),a
 ld a,30
 ld (pulse_timer),a
 call clear_screen
 call hud_base
 call reveal
 call bfs
 call render
 ld a,(clock)
 ld (last_loop),a
 ld (key_time),a
main:
 halt
 ld a,(clock)
 ld b,a
 ld hl,last_loop
 sub (hl)
 ld (hl),b
 ld (elapsed),a
 call read_keys
 ld (key),a
 cp 7
 jp z,pause_game
 ld b,a
 ld a,(last_key)
 cp b
 jr nz,new_key
 ld a,b
 or a
 jr z,timers
 cp 5
 jr nc,timers
 ld a,(clock)
 ld hl,key_time
 sub (hl)
 cp 6
 jr c,timers
new_key:
 ld a,b
 ld (last_key),a
 ld a,(clock)
 ld (key_time),a
 ld a,b
 or a
 jr z,timers
 cp 1
 call z,forward
 ld a,(key)
 cp 2
 call z,backward
 ld a,(key)
 cp 3
 call z,turn_left
 ld a,(key)
 cp 4
 call z,turn_right
 ld a,(key)
 cp 5
 call z,repel
 ld a,(key)
 cp 6
 call z,toggle_map
timers:
 ld a,(game_over)
 or a
 jp nz,ending
 ld a,(stun)
 or a
 jr z,enemy_clock
 ld hl,elapsed
 sub (hl)
 jr nc,stun_save
 xor a
stun_save:
 ld (stun),a
 jr pulse_clock
enemy_clock:
 ld a,(enemy_timer)
 ld hl,elapsed
 sub (hl)
 jr c,enemy_due
 jr z,enemy_due
 ld (enemy_timer),a
 jr pulse_clock
enemy_due:
 call chase
 ld a,(seals)
 add a,a
 add a,a
 ld b,a
 ld a,44
 sub b
 ld (enemy_timer),a
pulse_clock:
 ld a,(pulse_timer)
 ld hl,elapsed
 sub (hl)
 jr c,pulse_due
 jr z,pulse_due
 ld (pulse_timer),a
 jr maybe_render
pulse_due:
 ld a,(monster)
 ld l,a
 ld h,DIST/256
 ld a,(hl)
 cp 10
 jr nc,quiet_pulse
 push af
 ld b,9
 ld c,150
 call tone
 pop af
quiet_pulse:
 cp 20
 jr c,pulse_range
 ld a,20
pulse_range:
 add a,a
 add a,a
 add a,12
 ld (pulse_timer),a
maybe_render:
 ld a,(game_over)
 or a
 jp nz,ending
 ld a,(dirty)
 or a
 call nz,render
 jp main

irq:
 push af
 ld a,(clock)
 inc a
 ld (clock),a
 pop af
 ei
 reti

; Q/A forward/back, O/P turn, SPACE repel, M map, H pause.
read_keys:
 ld bc,64510
 in a,(c)
 bit 0,a
 ld a,1
 ret z
 ld bc,65022
 in a,(c)
 bit 0,a
 ld a,2
 ret z
 ld bc,57342
 in a,(c)
 bit 1,a
 ld a,3
 ret z
 in a,(c)
 bit 0,a
 ld a,4
 ret z
 ld bc,32766
 in a,(c)
 bit 0,a
 ld a,5
 ret z
 in a,(c)
 bit 2,a
 ld a,6
 ret z
 ld bc,49150
 in a,(c)
 bit 4,a
 ld a,7
 ret z
 xor a
 ret
wait_release:
 halt
 call read_keys
 or a
 jr nz,wait_release
 ret
wait_space:
 call wait_release
wait_space_loop:
 halt
 call read_keys
 cp 5
 jr nz,wait_space_loop
 jp wait_release
pause_game:
 ld hl,paused_text
 ld b,23
 ld c,0
 call text
 call wait_release
pause_loop:
 halt
 call read_keys
 cp 7
 jr nz,pause_loop
 call wait_release
 ld a,(clock)
 ld (last_loop),a
 call hud_base
 call render
 jp main
toggle_map:
 ld a,(map_mode)
 xor 1
 ld (map_mode),a
 jr mark_dirty
turn_left:
 ld a,(direction)
 dec a
 and 3
 ld (direction),a
 jr mark_dirty
turn_right:
 ld a,(direction)
 inc a
 and 3
 ld (direction),a
mark_dirty:
 ld a,1
 ld (dirty),a
 ret
delta:
 and 3
 ld e,a
 ld d,0
 ld hl,directions
 add hl,de
 ld a,(hl)
 ret
forward:
 ld a,(direction)
 call delta
 jr move
backward:
 ld a,(direction)
 add a,2
 call delta
move:
 ld b,a
 ld a,(player)
 add a,b
 ld l,a
 ld h,MAP/256
 ld a,(hl)
 cp 1
 jr z,bump
 ld a,l
 ld (player),a
 call collision
 ld a,(game_over)
 or a
 ret nz
 ld a,(hl)
 cp 2
 jr nz,check_exit
 ld (hl),0
 ld hl,seals
 inc (hl)
 ld b,32
 ld c,25
 call tone
check_exit:
 ld a,(player)
 ld l,a
 ld h,MAP/256
 ld a,(hl)
 cp 3
 jr nz,moved
 ld a,(seals)
 cp 3
 jr nz,moved
 ld a,2
 ld (game_over),a
moved:
 call reveal
 call bfs
 ld b,5
 ld c,60
 call tone
 jp mark_dirty
bump:
 ld b,4
 ld c,210
 jp tone
repel:
 ld a,(charges)
 or a
 ret z
 dec a
 ld (charges),a
 ld a,110
 ld (stun),a
 ld b,50
 ld c,60
 call tone
 jp mark_dirty
; Short beeper effect. Interrupts remain enabled; no ROM or AY chip.
tone:
 xor a
tone_outer:
 xor 16
 out (254),a
 ld e,c
tone_delay:
 dec e
 jr nz,tone_delay
 djnz tone_outer
 xor a
 out (254),a
 ret
collision:
 ld a,(monster)
 ld b,a
 ld a,(player)
 cp b
 ret nz
 ld a,1
 ld (game_over),a
 ret

; Breadth-first distance field; guarantees the monster navigates around walls.
bfs:
 ld hl,DIST
 ld de,DIST+1
 ld bc,255
 ld (hl),255
 ldir
 ld a,(player)
 ld l,a
 ld h,DIST/256
 ld (hl),0
 ld (QUEUE),a
 xor a
 ld (qhead),a
 ld a,1
 ld (qtail),a
bfs_loop:
 ld a,(qhead)
 ld l,a
 ld h,QUEUE/256
 ld a,(hl)
 ld (current),a
 ld l,a
 ld h,DIST/256
 ld a,(hl)
 inc a
 ld (next_dist),a
 ld ix,directions
 ld b,4
bfs_neighbors:
 ld a,(current)
 add a,(ix+0)
 ld l,a
 ld h,MAP/256
 ld a,(hl)
 cp 1
 jr z,bfs_skip
 ld h,DIST/256
 ld a,(hl)
 cp 255
 jr nz,bfs_skip
 ld a,(next_dist)
 ld (hl),a
 ld c,l
 ld a,(qtail)
 ld l,a
 ld h,QUEUE/256
 ld (hl),c
 inc a
 ld (qtail),a
bfs_skip:
 inc ix
 djnz bfs_neighbors
 ld hl,qhead
 inc (hl)
 ld a,(qtail)
 cp (hl)
 jr nz,bfs_loop
 ret
chase:
 call bfs
 ld a,(monster)
 ld (best_cell),a
 ld l,a
 ld h,DIST/256
 ld a,(hl)
 ld c,a
 ld ix,directions
 ld b,4
chase_neighbor:
 ld a,(monster)
 add a,(ix+0)
 ld l,a
 ld h,DIST/256
 ld a,(hl)
 cp c
 jr nc,chase_skip
 ld c,a
 ld a,l
 ld (best_cell),a
chase_skip:
 inc ix
 djnz chase_neighbor
 ld a,(best_cell)
 ld (monster),a
 call collision
 jp mark_dirty
reveal:
 ld a,(player)
 ld l,a
 ld h,SEEN/256
 ld (hl),1
 ld ix,directions
 ld b,4
reveal_loop:
 ld a,(player)
 add a,(ix+0)
 ld l,a
 ld (hl),1
 inc ix
 djnz reveal_loop
 ret

render:
 call clear_buffer
 ld a,(map_mode)
 or a
 jr z,render_view
 call draw_map
 jp render_done
render_view:
 ld a,(player)
 ld (view_cell),a
 xor a
 ld (depth),a
 ld a,255
 ld (visible_monster),a
 ld (visible_seal),a
 ld (visible_exit),a
view_loop:
 ; Visibility is recorded, objects are drawn after the architecture.
 ld a,(view_cell)
 ld l,a
 ld h,SEEN/256
 ld (hl),1
 ld h,MAP/256
 ld a,(hl)
 cp 2
 jr nz,view_no_seal
 ld a,(depth)
 ld (visible_seal),a
view_no_seal:
 ld a,(hl)
 cp 3
 jr nz,view_no_exit
 ld a,(depth)
 ld (visible_exit),a
view_no_exit:
 ld a,(monster)
 cp l
 jr nz,view_no_monster
 ld a,(depth)
 ld (visible_monster),a
view_no_monster:
 xor a
 ld (side),a
 call draw_side
 ld a,1
 ld (side),a
 call draw_side
 ld a,(direction)
 call delta
 ld b,a
 ld a,(view_cell)
 add a,b
 ld (view_cell),a
 ld l,a
 ld h,MAP/256
 ld a,(hl)
 cp 1
 jr z,view_front
 ld hl,depth
 inc (hl)
 ld a,(hl)
 cp 4
 jr c,view_loop
 jr view_objects
view_front:
 ld a,(depth)
 ld hl,front_table
 call table_word
 call blit
view_objects:
 ld a,(visible_exit)
 cp 255
 jr z,no_exit_sprite
 ld hl,exit_table
 call table_word
 call blit
no_exit_sprite:
 ld a,(visible_seal)
 cp 255
 jr z,no_seal_sprite
 ld hl,seal_table
 call table_word
 call blit
no_seal_sprite:
 ld a,(visible_monster)
 cp 255
 jr z,render_done
 ld hl,monster_erase_table
 call table_word
 call blit_erase
 ld a,(visible_monster)
 ld hl,monster_table
 call table_word
 call blit
render_done:
 call present
 call hud
 xor a
 ld (dirty),a
 ret
draw_side:
 ld a,(side)
 add a,a
 dec a
 ld b,a
 ld a,(direction)
 add a,b
 call delta
 ld b,a
 ld a,(view_cell)
 add a,b
 ld l,a
 ld h,SEEN/256
 ld (hl),1
 ld h,MAP/256
 ld a,(hl)
 cp 1
 ld c,0
 jr z,side_closed
 inc c
side_closed:
 ld a,(side)
 add a,a
 add a,c
 ld b,a
 ld a,(depth)
 add a,a
 add a,a
 add a,b
 ld hl,side_table
 call table_word
 jp blit
table_word:
 add a,a
 ld e,a
 ld d,0
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ex de,hl
 ret
; Sparse bitmap runs: little endian offset, count, OR bytes; FF high ends.
blit:
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 ld a,d
 cp 255
 ret z
 add a,BUFFER/256
 ld d,a
 ld b,(hl)
 inc hl
blit_run:
 ld a,(de)
 or (hl)
 ld (de),a
 inc de
 inc hl
 djnz blit_run
 jr blit
blit_erase:
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 ld a,d
 cp 255
 ret z
 add a,BUFFER/256
 ld d,a
 ld b,(hl)
 inc hl
erase_run:
 ld a,(de)
 and (hl)
 ld (de),a
 inc de
 inc hl
 djnz erase_run
 jr blit_erase
clear_buffer:
 ; Stack fill: 22,500 cycles vs 86,000 for LDIR. IM2 uses the normal stack.
 di
 ld (saved_sp),sp
 ld sp,BUFFER+4096
 ld de,0
 ld b,0
clear_fast:
 push de
 push de
 push de
 push de
 push de
 push de
 push de
 push de
 djnz clear_fast
 ld sp,(saved_sp)
 ei
 ret
; Linear buffer -> Spectrum interleaved bitmap, viewport y=16..143.
present:
 ld hl,BUFFER
 ld a,16
present_row:
 push af
 push hl
 call pixel_address
 ex de,hl
 pop hl
 ld bc,32
 rept 32
 ldi
 endm
 pop af
 inc a
 cp 144
 jr nz,present_row
 ; Cyan architecture; individual object attribute cells are precomputed.
 ld hl,22592
 ld de,22593
 ld bc,511
 ld (hl),69
 ldir
 ld a,(map_mode)
 or a
 ret nz
 ld a,(visible_exit)
 cp 255
 jr z,color_seal
 ld hl,exit_attr_table
 call table_word
 ld a,68
 call tint
color_seal:
 ld a,(visible_seal)
 cp 255
 jr z,color_monster
 ld hl,seal_attr_table
 call table_word
 ld a,70
 call tint
color_monster:
 ld a,(visible_monster)
 cp 255
 ret z
 ld hl,monster_attr_table
 call table_word
 ld a,66
tint:
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 inc d
 dec d
 ret z
 ld (de),a
 jr tint
; A = absolute pixel y, returns HL = leftmost byte.
pixel_address:
 ld l,a
 and 7
 or 64
 ld h,a
 ld a,l
 and 192
 rrca
 rrca
 rrca
 or h
 ld h,a
 ld a,l
 and 56
 rlca
 rlca
 ld l,a
 ret
clear_screen:
 ld hl,16384
 ld de,16385
 ld bc,6143
 ld (hl),0
 ldir
 ld hl,22528
 ld de,22529
 ld bc,767
 ld (hl),71
 ldir
 ret
; HL zero-terminated text; B char row; C column. Own font avoids ROM calls.
text:
 ld a,(hl)
 or a
 ret z
 push hl
 push bc
 sub 32
 ld l,a
 ld h,0
 add hl,hl
 add hl,hl
 add hl,hl
 ld de,font
 add hl,de
 push hl
 ld a,b
 add a,a
 add a,a
 add a,a
 call pixel_address
 ld a,l
 add a,c
 ld l,a
 ex de,hl
 pop hl
 ld b,8
text_glyph:
 ld a,(hl)
 ld (de),a
 inc hl
 inc d
 djnz text_glyph
 pop bc
 pop hl
 inc c
 ld a,c
 cp 32
 ret nc
 inc hl
 jr text
hud_base:
 ld hl,22528
 ld de,22529
 ld bc,31
 ld (hl),79
 ldir
 ld hl,23136
 ld de,23137
 ld bc,31
 ld (hl),70
 ldir
 ld hl,hud_title
 ld b,0
 ld c,0
 call text
 ld hl,controls_text
 ld b,23
 ld c,0
 jp text
hud:
 ld a,(seals)
 add a,48
 ld (hud_seals),a
 ld a,(charges)
 add a,48
 ld (hud_charges),a
 ld a,(direction)
 ld e,a
 ld d,0
 ld hl,compass
 add hl,de
 ld a,(hl)
 ld (hud_dir),a
 ld hl,hud_stats
 ld b,19
 ld c,0
 call text
 ld hl,far_text
 ld a,(monster)
 ld e,a
 ld d,DIST/256
 ld a,(de)
 cp 12
 jr nc,hud_threat
 ld hl,near_text
 cp 6
 jr nc,hud_threat
 ld hl,danger_text
hud_threat:
 ld a,(stun)
 or a
 jr z,hud_threat_show
 ld hl,stun_text
hud_threat_show:
 ld b,21
 ld c,0
 jp text
draw_map:
 xor a
 ld (map_index),a
map_loop:
 ld a,(map_index)
 ld l,a
 ld h,SEEN/256
 ld a,(hl)
 or a
 jr z,map_next
 ld h,MAP/256
 ld a,(hl)
 ld b,a
 ld a,(player)
 cp l
 jr nz,map_not_player
 ld b,4
map_not_player:
 ld a,b
 add a,a
 add a,a
 add a,a
 ld e,a
 ld d,0
 ld hl,map_tiles
 add hl,de
 push hl
 ld a,(map_index)
 and 240
 ld h,a
 ld l,0
 srl h
 rr l
 ; index row * 256 (8 scanlines *32) = high nibble /16 *256
 ld a,(map_index)
 and 240
 rrca
 rrca
 rrca
 rrca
 add a,BUFFER/256
 ld h,a
 ld a,(map_index)
 and 15
 add a,8
 ld l,a
 ex de,hl
 pop hl
 ld b,8
map_tile_row:
 ld a,(hl)
 ld (de),a
 inc hl
 ld a,e
 add a,32
 ld e,a
 jr nc,map_tile_no_carry
 inc d
map_tile_no_carry:
 djnz map_tile_row
map_next:
 ld hl,map_index
 inc (hl)
 jp nz,map_loop
 ret
ending:
 call render
 ld a,(game_over)
 cp 2
 jr z,victory
 ld hl,lost_text
 ld b,60
 ld c,180
 call tone
 ld hl,lost_text
 jr ending_show
victory:
 ld b,60
 ld c,30
 call tone
 ld hl,won_text
ending_show:
 ld b,21
 ld c,0
 call text
 ld hl,restart_text
 ld b,23
 ld c,0
 call text
 call wait_space
 jp new_game

directions: db 240,1,16,255
compass: db "NLSO"
clock: db 0
last_loop: db 0
elapsed: db 0
key_time: db 0
last_key: db 0
key: db 0
player: db 17
monster: db 0
direction: db 1
seals: db 0
charges: db 2
stun: db 0
map_mode: db 0
game_over: db 0
enemy_timer: db 0
pulse_timer: db 0
dirty: db 1
maze_id: db 0
qhead: db 0
qtail: db 0
current: db 0
next_dist: db 0
best_cell: db 0
depth: db 0
side: db 0
view_cell: db 0
visible_monster: db 255
visible_seal: db 255
visible_exit: db 255
saved_sp: dw 0
map_index: db 0
title: db "T R E V A S   -   T K 9 5",0
subtitle: db "O GUARDIAO DO LABIRINTO",0
intro1: db "ENCONTRE 3 SELOS E A SAIDA.",0
intro2: db "O GUARDIAO OUVE SEUS PASSOS.",0
intro3: db "SE O PULSO ACELERAR... CORRA!",0
intro4: db "Q/A ANDAR   O/P GIRAR",0
intro5: db "M MAPA  H PAUSA  SPACE ATORDOA",0
intro6: db "SPACE PARA ENTRAR",0
hud_title: db "TREVAS         O GUARDIAO   TK95",0
hud_stats: db "SELOS "
hud_seals: db "0/3  PULSOS "
hud_charges: db "2  RUMO "
hud_dir: db "L  ",0
far_text: db "PASSOS DISTANTES...              ",0
near_text: db "ELE ESTA SE APROXIMANDO!         ",0
danger_text: db "CORRA! ELE ESTA MUITO PERTO!     ",0
stun_text: db "GUARDIAO ATORDOADO - APROVEITE!  ",0
controls_text: db "Q/A ANDA O/P GIRA M MAPA H PAUSA ",0
paused_text: db "PAUSA - H PARA CONTINUAR         ",0
lost_text: db "O GUARDIAO ENCONTROU VOCE.       ",0
won_text: db "OS SELOS CEDERAM. VOCE ESCAPOU!  ",0
restart_text: db "SPACE PARA UM NOVO LABIRINTO     ",0
map_tiles:
 db 0,0,0,0,16,0,0,0
 db 126,66,126,8,126,66,126,0
 db 0,16,40,68,40,16,0,0
 db 126,66,90,82,90,66,126,0
 db 0,24,60,126,126,60,24,0

 include "assets.inc"
code_end:
; Machine-readable symbols used by tests (stored in binary footer).
 db "TREVASDBG"
 dw start,main,player,monster,direction,seals,charges,stun,game_over
 dw render,bfs,chase,forward,backward,turn_left,turn_right,repel
 dw maze_0,maze_1,maze_2,spawn_table,clock,irq,new_game,ending
 dw visible_monster,map_mode,enemy_timer,dirty,last_loop,wait_space_loop
 end start
