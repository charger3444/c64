; ====================================================================
; FIDATI. -- Commodore 64 port (Blocco 1: SPAZIO GEOMETRICO, liv. 1-3)
; Original game design & HTML5 source: Carlo Gerla
; C64 port: physics, hazards and sprite look ported natively to the
; VIC-II / SID, raster-IRQ driven, joystick-only control.
;
; Build: cl65 -t none -C c64-fidati.cfg -o fidati.prg fidati.s
; ====================================================================

.setcpu "6502"

; --------------------------------------------------------------------
; hardware registers
; --------------------------------------------------------------------
VIC_SPR0X   = $D000
VIC_SPR0Y   = $D001
VIC_CTRL1   = $D011
VIC_RASTER  = $D012
VIC_SPR_ENA = $D015
VIC_CTRL2   = $D016
VIC_SPR_XP  = $D01D
VIC_SPR_YP  = $D017
VIC_MEMPTR  = $D018
VIC_IRQFLAG = $D019
VIC_IRQEN   = $D01A
VIC_SPR_PRI = $D01B
VIC_SPR_MC  = $D01C
VIC_SPR_MSX = $D010
VIC_BORDER  = $D020
VIC_BG0     = $D021
VIC_BG1     = $D022
VIC_BG2     = $D023
VIC_SPRMC1  = $D025
VIC_SPRMC2  = $D026
VIC_SPR0COL = $D027

SID_V1FREQ  = $D400
SID_V1PW    = $D402
SID_V1CTRL  = $D404
SID_V1AD    = $D405
SID_V1SR    = $D406
SID_VOL     = $D418

CIA1_PRA    = $DC00
CIA1_PRB    = $DC01
CIA1_DDRA   = $DC02
CIA1_DDRB   = $DC03
CIA1_ICR    = $DC0D
CIA2_PRA    = $DD00

SCREEN      = $0400
COLORRAM    = $D800

IRQVEC      = $0314
NMIVEC      = $0318

; --------------------------------------------------------------------
; game constants
; --------------------------------------------------------------------
COLS = 20
ROWS = 12
NUMLEVELS = 3

PLW = 10                       ; player hitbox width  (px)
PLH = 13                       ; player hitbox height (px)

; fixed point: 7 fractional bits (value = pixels * 128)
FP_GRAV     = 72
FP_MAXFALL  = 1101
FP_MOVE     = 384
FP_MOVE_NEG = -384
FP_ACC_G    = 133
FP_ACC_A    = 87
FP_FRIC     = 118
FP_JUMPV    = -978
FP_JUMPCUT  = -358
COYOTE_FRAMES = 5
BUFFER_FRAMES = 6

SPAWN_FX = ((1*16+3)*128)      ; every level in block 1 spawns at col1,row9
SPAWN_FY = ((9*16+2)*128)

FAKE_TIMEOUT = 7                ; frames a fake floor shakes before it goes
FLAG_ANIM_PERIOD = 20            ; frames between pennant flips

; custom character codes (patched over the copied ROM font)
CH_SPACE     = 32
CH_TILE_TL   = 100
CH_TILE_TR   = 101
CH_TILE_BL   = 102
CH_TILE_BR   = 103
CH_SPIKE_BL  = 104
CH_SPIKE_BR  = 105
CH_FLAG_BL   = 106
CH_FLAG_TL_A = 107
CH_FLAG_TL_B = 108

COL_TILE   = 8
COL_SPIKE  = 2
COL_FLAGP  = 5      ; pennant, green
COL_POLE   = 1       ; pole, white
COL_BLANK  = 0

; tile grid types
T_EMPTY = 0
T_SOLID = 1
T_FAKE  = 2
T_SPIKE = 3
T_FLAGR = 4
T_FLAGX = 5
T_FLAGG = 6

; game states
ST_TITLE     = 0
ST_PLAY      = 1
ST_DEAD      = 2
ST_LEVELOUT  = 3
ST_BLOCKDONE = 4

; death causes
CAUSE_FALL  = 0
CAUSE_SPIKE = 1
CAUSE_XFLAG = 2

; --------------------------------------------------------------------
; macros
; --------------------------------------------------------------------
.macro SETW addr, val
    lda #<(val)
    sta addr
    lda #>(val)
    sta addr+1
.endmacro

.macro POKE addr, val
    lda #(val)
    sta addr
.endmacro

; ====================================================================
; zero page
; ====================================================================
.segment "ZEROPAGE"

tick:           .res 1
irq_stage:      .res 1

game_state:     .res 1
state_timer:    .res 1
cur_level:      .res 1

px_lo:  .res 1
px_hi:  .res 1
py_lo:  .res 1
py_hi:  .res 1
vx_lo:  .res 1
vx_hi:  .res 1
vy_lo:  .res 1
vy_hi:  .res 1

on_ground: .res 1
coyote:    .res 1
buffer:    .res 1

joy_left:  .res 1
joy_right: .res 1
joy_fire:  .res 1
fire_prev: .res 1
fire_edge: .res 1
face:      .res 1
anim_ctr:  .res 1

deaths_lvl: .res 1
deaths_tot: .res 1
score_lo:   .res 1
score_hi:   .res 1
clock_lo:   .res 1
clock_hi:   .res 1
grevealed:  .res 1
lastgain_lo: .res 1
lastgain_hi: .res 1
deathcause:  .res 1
rng:         .res 1

blocknum_r0: .res 1
sprframe:    .res 1
old_irq:     .res 2

; scratch
t0: .res 1
t1: .res 1
t2: .res 1
t3: .res 1

scrnptr:  .res 2
colorptr: .res 2
srcptr:   .res 2
dstptr:   .res 2

pix_lo: .res 1
pix_hi: .res 1
tc0: .res 1
tc1: .res 1
tr0: .res 1
tr1: .res 1

mul_lo: .res 1
mul_hi: .res 1
off_lo: .res 1
off_hi: .res 1

dt_col:  .res 1
dt_row:  .res 1
dt_type: .res 1

val_lo: .res 1
val_hi: .res 1
quot_lo: .res 1
quot_hi: .res 1
divisor: .res 1

msgptr:    .res 2
printcol:  .res 1
printrow:  .res 1
printcolor: .res 1

note_idx: .res 1

ov_pl_lo: .res 1
ov_pl_hi: .res 1
ov_pr_lo: .res 1
ov_pr_hi: .res 1
ov_pt_lo: .res 1
ov_pt_hi: .res 1
ov_pb_lo: .res 1
ov_pb_hi: .res 1
ov_tl_lo: .res 1
ov_tl_hi: .res 1
ov_tr_lo: .res 1
ov_tr_hi: .res 1
ov_tt_lo: .res 1
ov_tt_hi: .res 1
ov_tb_lo: .res 1
ov_tb_hi: .res 1
ov_pad:   .res 1

base_lo:  .res 1
base_hi:  .res 1
bonus_lo: .res 1
bonus_hi: .res 1

digitbuf: .res 5

; ====================================================================
; BASIC stub  ->  SYS 2061
; ====================================================================
.segment "LOADADDR"
    .word $0801

.segment "EXEHDR"
    .word basicstart
    .word 2020
    .byte $9E
    .byte "2061"
    .byte $00
basicstart:
    .word $0000

; ====================================================================
; entry point
; ====================================================================
.segment "CODE"

reset:
    sei
    ldx #$FF
    txs
    lda #$37              ; known-good memory config: BASIC+KERNAL+IO
    sta $01
    jsr init_hardware
    jsr copy_romfont
    jsr patch_charset
    jsr init_vars
    jsr install_irq
    cli
forever:
    jmp forever

; --------------------------------------------------------------------
init_hardware:
    lda CIA2_PRA
    and #%11111100        ; VIC bank 0
    sta CIA2_PRA

    POKE VIC_CTRL1, %00011011      ; text mode, 25 rows, DEN on
    POKE VIC_CTRL2, %00011000      ; multicolor chars, 40 col

    POKE VIC_BG0, 0                ; black background
    POKE VIC_BG1, 6                 ; tile base (blue)
    POKE VIC_BG2, 14                ; tile highlight (light blue)
    POKE VIC_BORDER, 0

    ; sprite 0 setup
    POKE VIC_SPR_ENA, 1
    POKE VIC_SPR_MC, 1
    POKE VIC_SPR_XP, 0
    POKE VIC_SPR_YP, 0
    POKE VIC_SPR_PRI, 0
    POKE VIC_SPR_MSX, 0
    POKE VIC_SPRMC1, 0               ; outline/eye -> black
    POKE VIC_SPRMC2, 8                ; cap -> orange
    POKE VIC_SPR0COL, 7               ; body -> yellow

    ; disable CIA1 IRQ sources so the VIC raster IRQ is the only one
    lda #$7F
    sta CIA1_ICR
    lda CIA1_ICR          ; reading clears any pending flags

    ; freeze the keyboard column driver so joystick port 2 reads clean
    lda #$FF
    sta CIA1_DDRA
    sta CIA1_PRA

    ; SID: full volume, filters off
    POKE SID_VOL, 15

    jsr clear_screen
    rts

; --------------------------------------------------------------------
; copy the "upper/graphics" character ROM ($D000-$D7FF) into our RAM
; charset buffer, briefly switching the char ROM into view.
; --------------------------------------------------------------------
copy_romfont:
    lda $01
    pha
    lda #%00110011        ; LORAM=1,HIRAM=1,CHAREN=0 -> char ROM
    sta $01               ; visible at $D000, KERNAL/BASIC still mapped

    SETW srcptr, $D000
    SETW dstptr, charset_buf
    ldx #8
@page:
    ldy #0
@byte:
    lda (srcptr),y
    sta (dstptr),y
    iny
    bne @byte
    inc srcptr+1
    inc dstptr+1
    dex
    bne @page

    pla
    sta $01
    rts

; --------------------------------------------------------------------
copy8:
    ldy #0
@l: lda (srcptr),y
    sta (dstptr),y
    iny
    cpy #8
    bne @l
    rts

.macro PATCHCHAR label, code
    SETW srcptr, label
    SETW dstptr, (charset_buf + (code*8))
    jsr copy8
.endmacro

patch_charset:
    PATCHCHAR glyph_tile_tl,   CH_TILE_TL
    PATCHCHAR glyph_tile_tr,   CH_TILE_TR
    PATCHCHAR glyph_tile_bl,   CH_TILE_BL
    PATCHCHAR glyph_tile_br,   CH_TILE_BR
    PATCHCHAR glyph_spike_bl,  CH_SPIKE_BL
    PATCHCHAR glyph_spike_br,  CH_SPIKE_BR
    PATCHCHAR glyph_flag_bl,   CH_FLAG_BL
    PATCHCHAR glyph_flag_tl_a, CH_FLAG_TL_A
    PATCHCHAR glyph_flag_tl_b, CH_FLAG_TL_B

    ; screen/char base register: screen=$0400 (field=1<<4=$10),
    ; charbase = charset_buf (2K aligned, so hi's low 3 bits are 0;
    ; field = (hi>>3)<<1 == hi>>2 exactly under that alignment)
    lda #>charset_buf
    lsr a
    lsr a
    ora #$10
    sta VIC_MEMPTR

    ; sprite pointer base = spr_player_r0 / 64 (64-byte aligned)
    lda #>spr_player_r0
    asl a
    asl a
    sta blocknum_r0
    lda #<spr_player_r0
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    clc
    adc blocknum_r0
    sta blocknum_r0
    rts

; --------------------------------------------------------------------
clear_screen:
    SETW dstptr, SCREEN
    lda #CH_SPACE
    ldx #4
@page1:
    ldy #0
@b1: sta (dstptr),y
    iny
    bne @b1
    inc dstptr+1
    dex
    bne @page1

    SETW dstptr, COLORRAM
    lda #COL_BLANK
    ldx #4
@page2:
    ldy #0
@b2: sta (dstptr),y
    iny
    bne @b2
    inc dstptr+1
    dex
    bne @page2
    rts

; --------------------------------------------------------------------
init_vars:
    lda #0
    sta tick
    sta irq_stage
    sta score_lo
    sta score_hi
    sta deaths_tot
    sta cur_level
    lda #170
    sta rng
    lda #ST_TITLE
    sta game_state
    lda #1
    sta state_timer     ; force first-frame redraw of title screen
    rts

; --------------------------------------------------------------------
install_irq:
    sei
    lda IRQVEC
    sta old_irq
    lda IRQVEC+1
    sta old_irq+1
    SETW IRQVEC, irq_handler
    SETW NMIVEC, nmi_stub   ; neutralise RESTORE-key/RS232 NMI: we
                            ; don't use either, just bounce straight
                            ; back out to be safe.
    POKE VIC_RASTER, 250
    lda VIC_CTRL1
    and #$7F
    sta VIC_CTRL1
    lda #$7F
    sta VIC_IRQEN          ; disable all VIC IRQ sources first
    lda #$FF
    sta VIC_IRQFLAG        ; ack/clear any stale pending flags
    POKE VIC_IRQEN, 1      ; enable raster IRQ only
    cli
    rts

; ====================================================================
; IRQ handler -- single raster stage per frame (line 250, bottom
; border): runs the whole game logic/render step, then re-arms.
; ====================================================================
irq_handler:
    pha
    txa
    pha
    tya
    pha

    jsr game_frame
    inc tick

    lda #$FF
    sta VIC_IRQFLAG

    pla
    tay
    pla
    tax
    pla
    rti

; RESTORE-key/RS232 NMI stub: this game uses neither, so just bail
; out immediately rather than trust the (untested) replacement KERNAL.
nmi_stub:
    rti

; ====================================================================
; per-frame dispatcher
; ====================================================================
game_frame:
    lda game_state
    cmp #ST_TITLE
    bne @c1
    jmp st_title
@c1:
    cmp #ST_PLAY
    bne @c2
    jmp st_play
@c2:
    cmp #ST_DEAD
    bne @c3
    jmp st_dead
@c3:
    cmp #ST_LEVELOUT
    bne @c4
    jmp st_levelout
@c4:
    jmp st_blockdone

; --------------------------------------------------------------------
; RNG: tiny 8-bit xorshift-ish LFSR, reseeded a bit by the joystick
; --------------------------------------------------------------------
next_rng:
    lda rng
    asl a
    bcc @noeor
    eor #$1D
@noeor:
    clc
    adc CIA1_PRB
    sta rng
    rts

.include "input.s"
.include "states.s"
.include "physics.s"
.include "level.s"
.include "render.s"
.include "sound.s"
.include "data.s"

; ====================================================================
; large uninitialised areas (kept as real, zero-filled bytes so file
; offsets stay in lock-step with runtime addresses)
; ====================================================================
.segment "DATA"

cur_grid:     .res 240
shaker_col:   .res 8
shaker_row:   .res 8
shaker_timer: .res 8
shaker_count: .res 1

spike_col: .res 4
spike_row: .res 4
spike_count: .res 1

flag_col:  .res 4
flag_row:  .res 4
flag_kind: .res 4
flag_count: .res 1

flaganim_lo: .res 4
flaganim_hi: .res 4
flaganim_count: .res 1
flaganim_phase: .res 1
flaganim_timer: .res 1

.segment "CHARBUF"
charset_buf: .res $0800
