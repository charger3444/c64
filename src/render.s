; ====================================================================
; rendering: tiles, sprite, HUD, text overlays
; ====================================================================

; --------------------------------------------------------------------
; calc_tile_addrs: dt_col/dt_row (tile coords) -> scrnptr/colorptr
; (address of the TOP-LEFT of the 2x2 char block for that tile)
; --------------------------------------------------------------------
calc_tile_addrs:
    lda dt_row
    jsr mul_row80
    lda mul_lo
    clc
    adc #40
    sta off_lo
    lda mul_hi
    adc #0
    sta off_hi
    lda dt_col
    asl a
    clc
    adc off_lo
    sta off_lo
    lda off_hi
    adc #0
    sta off_hi
    lda off_lo
    sta scrnptr
    lda off_hi
    clc
    adc #>SCREEN
    sta scrnptr+1
    lda off_lo
    sta colorptr
    lda off_hi
    clc
    adc #>COLORRAM
    sta colorptr+1
    rts

mul_row80:                 ; A=row(0-11) -> mul_lo/hi = row*80
    sta t2
    lda #0
    sta mul_lo
    sta mul_hi
@loop:
    lda t2
    beq @done
    lda mul_lo
    clc
    adc #80
    sta mul_lo
    lda mul_hi
    adc #0
    sta mul_hi
    dec t2
    jmp @loop
@done:
    rts

mul_row40:                 ; A=row(0-24) -> mul_lo/hi = row*40
    sta t2
    lda #0
    sta mul_lo
    sta mul_hi
@loop:
    lda t2
    beq @done
    lda mul_lo
    clc
    adc #40
    sta mul_lo
    lda mul_hi
    adc #0
    sta mul_hi
    dec t2
    jmp @loop
@done:
    rts

; --------------------------------------------------------------------
; draw_tile: dt_col, dt_row, dt_type -> pokes the 2x2 char block
; --------------------------------------------------------------------
draw_tile:
    jsr calc_tile_addrs
    lda dt_type
    cmp #T_SOLID
    beq @gotosolid
    cmp #T_FAKE
    beq @gotosolid
    cmp #T_SPIKE
    beq @gotospike
    cmp #T_FLAGR
    beq @gotoflag
    cmp #T_FLAGX
    beq @gotoflag
    cmp #T_FLAGG
    beq @gotoghost
    jmp @empty
@gotosolid:
    jmp @solid
@gotospike:
    jmp @spike
@gotoflag:
    jmp @flag
@gotoghost:
    jmp @ghost

@solid:
    ldy #0
    lda #CH_TILE_TL
    sta (scrnptr),y
    lda #COL_TILE
    sta (colorptr),y
    ldy #1
    lda #CH_TILE_TR
    sta (scrnptr),y
    lda #COL_TILE
    sta (colorptr),y
    ldy #40
    lda #CH_TILE_BL
    sta (scrnptr),y
    lda #COL_TILE
    sta (colorptr),y
    ldy #41
    lda #CH_TILE_BR
    sta (scrnptr),y
    lda #COL_TILE
    sta (colorptr),y
    rts

@spike:
    ldy #0
    lda #CH_SPACE
    sta (scrnptr),y
    lda #COL_BLANK
    sta (colorptr),y
    ldy #1
    lda #CH_SPACE
    sta (scrnptr),y
    lda #COL_BLANK
    sta (colorptr),y
    ldy #40
    lda #CH_SPIKE_BL
    sta (scrnptr),y
    lda #COL_SPIKE
    sta (colorptr),y
    ldy #41
    lda #CH_SPIKE_BR
    sta (scrnptr),y
    lda #COL_SPIKE
    sta (colorptr),y
    rts

@flag:
    ldy #0
    lda #CH_FLAG_TL_A
    sta (scrnptr),y
    lda #COL_FLAGP
    sta (colorptr),y
    ldy #1
    lda #CH_SPACE
    sta (scrnptr),y
    lda #COL_BLANK
    sta (colorptr),y
    ldy #40
    lda #CH_FLAG_BL
    sta (scrnptr),y
    lda #COL_POLE
    sta (colorptr),y
    ldy #41
    lda #CH_SPACE
    sta (scrnptr),y
    lda #COL_BLANK
    sta (colorptr),y
    jsr register_flag_anim
    rts

@ghost:
    lda grevealed
    bne @flag
    jmp @empty

@empty:
    ldy #0
    lda #CH_SPACE
    sta (scrnptr),y
    lda #COL_BLANK
    sta (colorptr),y
    ldy #1
    lda #CH_SPACE
    sta (scrnptr),y
    lda #COL_BLANK
    sta (colorptr),y
    ldy #40
    lda #CH_SPACE
    sta (scrnptr),y
    lda #COL_BLANK
    sta (colorptr),y
    ldy #41
    lda #CH_SPACE
    sta (scrnptr),y
    lda #COL_BLANK
    sta (colorptr),y
    rts

; register_flag_anim: remembers the current scrnptr (TL char address)
; so the pennant can be flipped between frames periodically
register_flag_anim:
    ldx flaganim_count
    cpx #4
    bcs @done
    lda scrnptr
    sta flaganim_lo,x
    lda scrnptr+1
    sta flaganim_hi,x
    inc flaganim_count
@done:
    rts

; --------------------------------------------------------------------
; draw_level: redraws the whole 20x12 grid from cur_grid
; --------------------------------------------------------------------
draw_level:
    lda #0
    sta flaganim_count
    jsr clear_screen
    lda #0
    sta t1
@rowloop:
    lda #0
    sta t0
@colloop:
    jsr grid_index
    ldy #0
    lda (dstptr),y
    beq @skip
    sta dt_type
    lda t0
    sta dt_col
    lda t1
    sta dt_row
    jsr draw_tile
@skip:
    inc t0
    lda t0
    cmp #COLS
    bne @colloop
    inc t1
    lda t1
    cmp #ROWS
    bne @rowloop
    rts

; --------------------------------------------------------------------
; update_flag_anim: periodically flips every registered flag pennant
; --------------------------------------------------------------------
update_flag_anim:
    inc flaganim_timer
    lda flaganim_timer
    cmp #FLAG_ANIM_PERIOD
    bcc @done
    lda #0
    sta flaganim_timer
    lda flaganim_phase
    eor #1
    sta flaganim_phase
    lda flaganim_count
    beq @done
    ldx #0
@loop:
    lda flaganim_lo,x
    sta scrnptr
    lda flaganim_hi,x
    sta scrnptr+1
    lda flaganim_phase
    beq @useA
    lda #CH_FLAG_TL_B
    jmp @store
@useA:
    lda #CH_FLAG_TL_A
@store:
    ldy #0
    sta (scrnptr),y
    inx
    cpx flaganim_count
    bne @loop
@done:
    rts

; ====================================================================
; sprite positioning
; ====================================================================
SPR_X_ADD = 17
SPR_Y_ADD = 54

update_sprite:
    jsr fixed_to_pixel_x
    lda pix_lo
    clc
    adc #SPR_X_ADD
    sta VIC_SPR0X
    lda pix_hi
    adc #0
    beq @clearmsb
    lda VIC_SPR_MSX
    ora #1
    sta VIC_SPR_MSX
    jmp @xdone
@clearmsb:
    lda VIC_SPR_MSX
    and #%11111110
    sta VIC_SPR_MSX
@xdone:

    jsr fixed_to_pixel_y
    lda pix_lo
    clc
    adc #SPR_Y_ADD
    sta VIC_SPR0Y

    lda on_ground
    bne @grounded
    lda face
    beq @jr
    lda #5
    jmp @haveframe
@jr:
    lda #2
    jmp @haveframe
@grounded:
    lda vx_lo
    ora vx_hi
    beq @idle
    lda anim_ctr
    and #8
    beq @f0
    lda face
    beq @r1
    lda #4
    jmp @haveframe
@r1:
    lda #1
    jmp @haveframe
@f0:
    lda face
    beq @r0
    lda #3
    jmp @haveframe
@r0:
    lda #0
    jmp @haveframe
@idle:
    lda face
    beq @idleR
    lda #3
    jmp @haveframe
@idleR:
    lda #0
@haveframe:
    sta sprframe
    lda blocknum_r0
    clc
    adc sprframe
    sta $07F8
    rts

; ====================================================================
; text printing
; ====================================================================
calc_char_addr:
    lda printrow
    jsr mul_row40
    lda mul_lo
    clc
    adc printcol
    sta off_lo
    lda mul_hi
    adc #0
    sta off_hi
    lda off_lo
    sta scrnptr
    lda off_hi
    clc
    adc #>SCREEN
    sta scrnptr+1
    lda off_lo
    sta colorptr
    lda off_hi
    clc
    adc #>COLORRAM
    sta colorptr+1
    rts

; print_pascal: msgptr -> length-prefixed screencode string, printed
; at printrow/printcol in printcolor
print_pascal:
    jsr calc_char_addr
    ldy #0
    lda (msgptr),y
    sta t3
    inc msgptr
    bne @noc
    inc msgptr+1
@noc:
    ldy #0
@loop:
    cpy t3
    beq @done
    lda (msgptr),y
    sta (scrnptr),y
    lda printcolor
    sta (colorptr),y
    iny
    jmp @loop
@done:
    rts

; print_dec: prints val_lo/val_hi in decimal, A=digit count (leading
; zeros), at printrow/printcol in printcolor
print_dec:
    sta t0
    ldx #0
@gen:
    lda #10
    jsr div_by_const
    lda val_lo
    sta digitbuf,x
    inx
    lda quot_lo
    sta val_lo
    lda quot_hi
    sta val_hi
    cpx t0
    bne @gen

    jsr calc_char_addr
    ldx t0
    dex
    ldy #0
@print:
    lda digitbuf,x
    clc
    adc #48
    sta (scrnptr),y
    lda printcolor
    sta (colorptr),y
    iny
    dex
    bpl @print
    rts

; ====================================================================
; HUD
; ====================================================================
draw_hud_static:
    lda #0
    sta printrow
    lda #1
    sta printcol
    lda #1
    sta printcolor
    SETW msgptr, txt_hud_morti
    jsr print_pascal

    lda #0
    sta printrow
    lda #14
    sta printcol
    SETW msgptr, txt_hud_punti
    jsr print_pascal

    lda #0
    sta printrow
    lda #28
    sta printcol
    SETW msgptr, txt_hud_liv
    jsr print_pascal

    jsr update_hud
    rts

update_hud:
    lda #0
    sta printrow
    lda #8
    sta printcol
    lda #1
    sta printcolor
    lda deaths_lvl
    sta val_lo
    lda #0
    sta val_hi
    lda #2
    jsr print_dec

    lda #0
    sta printrow
    lda #21
    sta printcol
    lda score_lo
    sta val_lo
    lda score_hi
    sta val_hi
    lda #4
    jsr print_dec

    lda #0
    sta printrow
    lda #33
    sta printcol
    lda cur_level
    clc
    adc #1
    sta val_lo
    lda #0
    sta val_hi
    lda #1
    jsr print_dec
    rts

; ====================================================================
; full-screen text overlays
; ====================================================================
draw_title_screen:
    jsr clear_screen

    lda #4
    sta printrow
    lda #15
    sta printcol
    lda #7
    sta printcolor
    SETW msgptr, txt_title
    jsr print_pascal

    lda #7
    sta printrow
    lda #7
    sta printcol
    lda #3
    sta printcolor
    SETW msgptr, txt_subtitle
    jsr print_pascal

    lda #11
    sta printrow
    lda #12
    sta printcol
    lda #1
    sta printcolor
    SETW msgptr, txt_howto1
    jsr print_pascal

    lda #12
    sta printrow
    lda #3
    sta printcol
    SETW msgptr, txt_howto2
    jsr print_pascal

    lda #16
    sta printrow
    lda #8
    sta printcol
    lda #5
    sta printcolor
    SETW msgptr, txt_press
    jsr print_pascal

    lda #21
    sta printrow
    lda #8
    sta printcol
    lda #1
    sta printcolor
    SETW msgptr, txt_credit
    jsr print_pascal

    lda #22
    sta printrow
    lda #7
    sta printcol
    SETW msgptr, txt_port
    jsr print_pascal
    rts

; --------------------------------------------------------------------
; pick_death_message: uses deathcause -> sets msgptr to a random
; message from the matching quip category
; --------------------------------------------------------------------
death_table_fall:
    .word txt_fall1, txt_fall2, txt_fall3, txt_fall4
death_table_spike:
    .word txt_spike1, txt_spike2, txt_spike3, txt_spike4
death_table_xflag:
    .word txt_xflag1, txt_xflag2, txt_xflag3, txt_xflag4

pick_death_message:
    jsr next_rng
    and #3
    sta t1
    lda deathcause
    cmp #CAUSE_SPIKE
    beq @spiketab
    cmp #CAUSE_XFLAG
    beq @xflagtab
    SETW srcptr, death_table_fall
    jmp @fetch
@spiketab:
    SETW srcptr, death_table_spike
    jmp @fetch
@xflagtab:
    SETW srcptr, death_table_xflag
@fetch:
    lda t1
    asl a
    tay
    lda (srcptr),y
    sta msgptr
    iny
    lda (srcptr),y
    sta msgptr+1
    rts

; --------------------------------------------------------------------
draw_dead_overlay:
    jsr pick_death_message
    lda #10
    sta printrow
    lda #2
    sta printcol
    lda #2
    sta printcolor
    jsr print_pascal

    lda #13
    sta printrow
    lda #12
    sta printcol
    lda #1
    sta printcolor
    SETW msgptr, txt_deaths_lbl
    jsr print_pascal
    lda #18
    sta printcol
    lda deaths_lvl
    sta val_lo
    lda #0
    sta val_hi
    lda #2
    jsr print_dec
    rts

; --------------------------------------------------------------------
draw_levelout_overlay:
    lda #9
    sta printrow
    lda #10
    sta printcol
    lda #5
    sta printcolor
    SETW msgptr, txt_completed
    jsr print_pascal

    lda #12
    sta printrow
    lda #15
    sta printcol
    lda #7
    sta printcolor
    SETW msgptr, txt_gain_pre
    jsr print_pascal
    lda #16
    sta printcol
    lda lastgain_lo
    sta val_lo
    lda lastgain_hi
    sta val_hi
    lda #4
    jsr print_dec
    lda #20
    sta printcol
    SETW msgptr, txt_gain_post
    jsr print_pascal

    lda #15
    sta printrow
    lda #12
    sta printcol
    lda #1
    sta printcolor
    SETW msgptr, txt_notrust
    jsr print_pascal
    rts

; --------------------------------------------------------------------
draw_blockdone_screen:
    jsr clear_screen

    lda #5
    sta printrow
    lda #9
    sta printcol
    lda #5
    sta printcolor
    SETW msgptr, txt_block_done
    jsr print_pascal

    lda #9
    sta printrow
    lda #8
    sta printcol
    lda #7
    sta printcolor
    SETW msgptr, txt_score_tot
    jsr print_pascal
    lda #21
    sta printcol
    lda score_lo
    sta val_lo
    lda score_hi
    sta val_hi
    lda #4
    jsr print_dec

    lda #11
    sta printrow
    lda #8
    sta printcol
    lda #2
    sta printcolor
    SETW msgptr, txt_deaths_tot
    jsr print_pascal
    lda #21
    sta printcol
    lda deaths_tot
    sta val_lo
    lda #0
    sta val_hi
    lda #2
    jsr print_dec

    lda #16
    sta printrow
    lda #7
    sta printcol
    lda #3
    sta printcolor
    SETW msgptr, txt_restart
    jsr print_pascal
    rts
