; ====================================================================
; level loading, drawing, and per-frame hazard checks
; ====================================================================

; --------------------------------------------------------------------
; load_level: cur_level (0..2) selects the ROM grid to copy in, builds
; the spike/flag lists, clears gRevealed, draws, and respawns.
; --------------------------------------------------------------------
load_level:
    lda cur_level
    beq @l0
    cmp #1
    beq @l1
    SETW srcptr, level3_grid
    jmp @copy
@l0:
    SETW srcptr, level1_grid
    jmp @copy
@l1:
    SETW srcptr, level2_grid

@copy:
    SETW dstptr, cur_grid
    ldy #0
@page:
    lda (srcptr),y
    sta (dstptr),y
    iny
    cpy #240
    bne @page

    lda #0
    sta grevealed
    sta shaker_count
    jsr build_lists
    jsr respawn
    rts

; --------------------------------------------------------------------
; respawn: reset the grid (undo crumbled tiles), player state, redraw
; the level, and reset the flag pennant animation registry
; --------------------------------------------------------------------
respawn:
    lda cur_level
    beq @l0
    cmp #1
    beq @l1
    SETW srcptr, level3_grid
    jmp @copy
@l0:
    SETW srcptr, level1_grid
    jmp @copy
@l1:
    SETW srcptr, level2_grid
@copy:
    SETW dstptr, cur_grid
    ldy #0
@page:
    lda (srcptr),y
    sta (dstptr),y
    iny
    cpy #240
    bne @page

    lda #0
    sta shaker_count

    SETW px_lo, SPAWN_FX
    SETW py_lo, SPAWN_FY
    lda #0
    sta vx_lo
    sta vx_hi
    sta vy_lo
    sta vy_hi
    sta on_ground
    sta coyote
    sta buffer
    sta face
    sta clock_lo
    sta clock_hi

    jsr draw_level
    jsr draw_hud_static
    rts

; --------------------------------------------------------------------
; build_lists: scan cur_grid once, collect spike/flag tile coords
; --------------------------------------------------------------------
build_lists:
    lda #0
    sta spike_count
    sta flag_count
    lda #0
    sta t0                ; col
    sta t1                ; row
    SETW srcptr, cur_grid
@loop:
    ldy #0
    lda (srcptr),y
    cmp #T_SPIKE
    bne @notspike
    ldx spike_count
    cpx #4
    bcs @notspike
    lda t0
    sta spike_col,x
    lda t1
    sta spike_row,x
    inc spike_count
@notspike:
    ldy #0
    lda (srcptr),y
    cmp #T_FLAGR
    beq @isflag
    cmp #T_FLAGX
    beq @isflag
    cmp #T_FLAGG
    beq @isflag
    jmp @advance
@isflag:
    ldx flag_count
    cpx #4
    bcs @advance
    lda t0
    sta flag_col,x
    lda t1
    sta flag_row,x
    ldy #0
    lda (srcptr),y
    sta flag_kind,x
    inc flag_count
@advance:
    inc srcptr
    bne @nc
    inc srcptr+1
@nc:
    inc t0
    lda t0
    cmp #COLS
    bne @loop
    lda #0
    sta t0
    inc t1
    lda t1
    cmp #ROWS
    bne @loop
    rts

; ====================================================================
; play_hazards -- called once per frame while state==PLAY
; ====================================================================
play_hazards:
    jsr check_fake_trigger
    jsr update_shakers
    jsr check_spikes
    jsr check_flags
    jsr check_fall
    rts

; --------------------------------------------------------------------
; check_fake_trigger: while on the ground, any FAKE tile directly
; under the feet starts shaking
; --------------------------------------------------------------------
check_fake_trigger:
    lda on_ground
    beq @done
    jsr calc_bounds_current
    lda tr1
    sta t1
    lda tc0
    sta t0
@loop:
    jsr grid_index
    ldy #0
    lda (dstptr),y
    cmp #T_FAKE
    bne @next
    ; is it already tracked as shaking?
    jsr find_shaker
    cmp #$FF
    bne @next
    ldx shaker_count
    cpx #8
    bcs @next
    lda t0
    sta shaker_col,x
    lda t1
    sta shaker_row,x
    lda #0
    sta shaker_timer,x
    inc shaker_count
@next:
    lda t0
    cmp tc1
    beq @done
    inc t0
    jmp @loop
@done:
    rts

; find_shaker: t0=col,t1=row -> A = index or $FF if not found
find_shaker:
    ldx #0
    lda shaker_count
    beq @none
    stx t2
@loop:
    ldx t2
    lda shaker_col,x
    cmp t0
    bne @next
    lda shaker_row,x
    cmp t1
    bne @next
    lda t2
    rts
@next:
    inc t2
    lda t2
    cmp shaker_count
    bne @loop
@none:
    lda #$FF
    rts

; --------------------------------------------------------------------
; update_shakers: advance timers; when one expires, remove the tile
; (grid -> empty) and redraw it as a hole
; --------------------------------------------------------------------
update_shakers:
    lda shaker_count
    beq @done
    lda #0
    sta t2
@loop:
    ldx t2
    inc shaker_timer,x
    lda shaker_timer,x
    cmp #FAKE_TIMEOUT
    bcc @keep
    ; expire this one: clear the grid cell and redraw as empty
    lda shaker_col,x
    sta t0
    sta dt_col
    lda shaker_row,x
    sta t1
    sta dt_row
    jsr grid_index
    lda #T_EMPTY
    ldy #0
    sta (dstptr),y
    lda #T_EMPTY
    sta dt_type
    jsr draw_tile
    jsr snd_crumble
    ; remove from list by swapping with last
    ldx t2
    ldy shaker_count
    dey
    lda shaker_col,y
    sta shaker_col,x
    lda shaker_row,y
    sta shaker_row,x
    lda shaker_timer,y
    sta shaker_timer,x
    dec shaker_count
    lda shaker_count
    cmp t2
    beq @done
    jmp @loop2chk
@keep:
    inc t2
@loop2chk:
    lda t2
    cmp shaker_count
    bcc @loop
@done:
    rts

; --------------------------------------------------------------------
; check_spikes: static hazard, AABB overlap with pad=4 (matches JS)
; --------------------------------------------------------------------
check_spikes:
    lda spike_count
    beq @done
    lda #0
    sta t2
@loop:
    ldx t2
    lda spike_col,x
    sta t0
    lda spike_row,x
    sta t1
    jsr overlap_tile4
    cmp #1
    bne @next
    lda #CAUSE_SPIKE
    jsr die
    rts
@next:
    inc t2
    lda t2
    cmp spike_count
    bne @loop
@done:
    rts

; --------------------------------------------------------------------
; check_flags
; --------------------------------------------------------------------
check_flags:
    lda flag_count
    beq @done
    lda #0
    sta t2
@loop:
    ldx t2
    lda flag_col,x
    sta t0
    lda flag_row,x
    sta t1
    jsr overlap_tile2
    cmp #1
    bne @next
    lda flag_kind,x
    cmp #T_FLAGR
    beq @real
    cmp #T_FLAGX
    beq @fake
    ; ghost
    lda grevealed
    beq @next
    jmp @real
@fake:
    lda #1
    sta grevealed
    ; (re)draw the ghost flag tiles now that it's revealed, and
    ; register any newly-visible pennants for animation
    jsr reveal_ghost_flags
    lda #CAUSE_XFLAG
    jsr die
    rts
@real:
    jsr complete_level
    rts
@next:
    inc t2
    lda t2
    cmp flag_count
    bne @loop
@done:
    rts

; reveal_ghost_flags: redraw any ghost-kind flag tiles now that
; grevealed=1, and register their pennants for animation
reveal_ghost_flags:
    lda flag_count
    beq @done
    lda #0
    sta t2
@loop:
    ldx t2
    lda flag_kind,x
    cmp #T_FLAGG
    bne @next
    lda flag_col,x
    sta dt_col
    sta t0
    lda flag_row,x
    sta dt_row
    sta t1
    lda #T_FLAGG
    sta dt_type
    jsr draw_tile
@next:
    inc t2
    lda t2
    cmp flag_count
    bne @loop
@done:
    rts

; --------------------------------------------------------------------
; overlap_tile4 / overlap_tile2: AABB overlap between the player box
; and tile (t0=col,t1=row) with the given inward padding (matches the
; JS overlapTile pad). Returns A=1 if overlapping, else 0.
; --------------------------------------------------------------------
overlap_tile4:
    lda #4
    sta ov_pad
    jmp overlap_tile_do
overlap_tile2:
    lda #2
    sta ov_pad
overlap_tile_do:
    ; -------- tile horizontal bounds --------
    lda t0
    jsr tiles_to_pixel16          ; pix = col*16
    lda pix_lo
    clc
    adc ov_pad
    sta ov_tl_lo
    lda pix_hi
    adc #0
    sta ov_tl_hi

    lda pix_lo
    clc
    adc #16
    sec
    sbc ov_pad
    sta ov_tr_lo
    lda pix_hi
    adc #0
    sta ov_tr_hi

    ; -------- tile vertical bounds --------
    lda t1
    jsr tiles_to_pixel16          ; pix = row*16
    lda pix_lo
    clc
    adc ov_pad
    sta ov_tt_lo
    lda pix_hi
    adc #0
    sta ov_tt_hi

    lda pix_lo
    clc
    adc #16
    sec
    sbc ov_pad
    sta ov_tb_lo
    lda pix_hi
    adc #0
    sta ov_tb_hi

    ; -------- player bounds --------
    jsr fixed_to_pixel_x
    lda pix_lo
    sta ov_pl_lo
    lda pix_hi
    sta ov_pl_hi
    lda pix_lo
    clc
    adc #PLW
    sta ov_pr_lo
    lda pix_hi
    adc #0
    sta ov_pr_hi

    jsr fixed_to_pixel_y
    lda pix_lo
    sta ov_pt_lo
    lda pix_hi
    sta ov_pt_hi
    lda pix_lo
    clc
    adc #PLH
    sta ov_pb_lo
    lda pix_hi
    adc #0
    sta ov_pb_hi

    ; -------- overlap tests --------
    ; playerLeft < tileRight ?
    lda ov_pl_hi
    cmp ov_tr_hi
    bcc @c1yes
    bne @no
    lda ov_pl_lo
    cmp ov_tr_lo
    bcc @c1yes
    jmp @no
@c1yes:
    ; playerRight > tileLeft ?  (i.e. tileLeft < playerRight)
    lda ov_tl_hi
    cmp ov_pr_hi
    bcc @c2yes
    bne @no
    lda ov_tl_lo
    cmp ov_pr_lo
    bcc @c2yes
    jmp @no
@c2yes:
    ; playerTop < tileBottom ?
    lda ov_pt_hi
    cmp ov_tb_hi
    bcc @c3yes
    bne @no
    lda ov_pt_lo
    cmp ov_tb_lo
    bcc @c3yes
    jmp @no
@c3yes:
    ; playerBottom > tileTop ?  (tileTop < playerBottom)
    lda ov_tt_hi
    cmp ov_pb_hi
    bcc @yes
    bne @no
    lda ov_tt_lo
    cmp ov_pb_lo
    bcc @yes
@no:
    lda #0
    rts
@yes:
    lda #1
    rts

; --------------------------------------------------------------------
check_fall:
    jsr fixed_to_pixel_y
    lda pix_hi
    bne @falldeath
    lda pix_lo
    cmp #200
    bcc @done
@falldeath:
    lda #CAUSE_FALL
    jsr die
@done:
    rts

; --------------------------------------------------------------------
; die: cause in A. Only takes effect while state==PLAY.
; --------------------------------------------------------------------
die:
    pha
    lda game_state
    cmp #ST_PLAY
    beq @proceed
    pla
    rts
@proceed:
    pla
    sta deathcause
    lda #ST_DEAD
    sta game_state
    lda #0
    sta state_timer
    inc deaths_lvl
    inc deaths_tot
    jsr snd_death
    rts

; --------------------------------------------------------------------
; complete_level: only from PLAY. Scores, then hands off to LEVELOUT.
; --------------------------------------------------------------------
complete_level:
    lda game_state
    cmp #ST_PLAY
    bne @done
    jsr compute_score_gain
    lda #ST_LEVELOUT
    sta game_state
    lda #0
    sta state_timer
@done:
    rts

; --------------------------------------------------------------------
; compute_score_gain: base=max(100,1000-deaths_lvl*100)
;                     bonus=max(0,600-floor(clock/50)*20)
;                     lastgain=base+bonus ; score+=lastgain
; --------------------------------------------------------------------
compute_score_gain:
    ; ---- deaths_lvl * 100 ----
    lda deaths_lvl
    sta t0
    lda #0
    sta val_lo
    sta val_hi
@mulloop:
    lda t0
    beq @muldone
    lda val_lo
    clc
    adc #100
    sta val_lo
    lda val_hi
    adc #0
    sta val_hi
    dec t0
    jmp @mulloop
@muldone:
    lda #<1000
    sec
    sbc val_lo
    sta base_lo
    lda #>1000
    sbc val_hi
    sta base_hi
    bcc @baseclamp
    lda base_hi
    bne @basedone
    lda base_lo
    cmp #100
    bcs @basedone
@baseclamp:
    lda #100
    sta base_lo
    lda #0
    sta base_hi
@basedone:

    ; ---- floor(clock/50) ----
    lda clock_lo
    sta val_lo
    lda clock_hi
    sta val_hi
    lda #50
    jsr div_by_const          ; quot_lo/hi = val/50

    ; ---- quot*20 = (quot<<2)+(quot<<4) ----
    lda quot_lo
    sta mul_lo
    lda quot_hi
    sta mul_hi
    asl mul_lo
    rol mul_hi
    asl mul_lo
    rol mul_hi
    lda mul_lo
    sta off_lo
    lda mul_hi
    sta off_hi
    asl mul_lo
    rol mul_hi
    asl mul_lo
    rol mul_hi
    lda off_lo
    clc
    adc mul_lo
    sta off_lo
    lda off_hi
    adc mul_hi
    sta off_hi

    ; ---- bonus = 600 - quot*20, clamp >=0 ----
    lda #<600
    sec
    sbc off_lo
    sta bonus_lo
    lda #>600
    sbc off_hi
    sta bonus_hi
    bcc @bonusclamp
    jmp @bonusdone
@bonusclamp:
    lda #0
    sta bonus_lo
    sta bonus_hi
@bonusdone:

    ; ---- lastgain = base+bonus ; score += lastgain ----
    lda base_lo
    clc
    adc bonus_lo
    sta lastgain_lo
    lda base_hi
    adc bonus_hi
    sta lastgain_hi

    lda score_lo
    clc
    adc lastgain_lo
    sta score_lo
    lda score_hi
    adc lastgain_hi
    sta score_hi
    rts

; --------------------------------------------------------------------
; div_by_const: divides val_lo/val_hi by the constant in A (<=255),
; result (quotient) in quot_lo/quot_hi. Remainder is discarded.
; --------------------------------------------------------------------
div_by_const:
    sta divisor
    lda #0
    sta quot_lo
    sta quot_hi
@loop:
    lda val_hi
    bne @cont
    lda val_lo
    cmp divisor
    bcc @done
@cont:
    lda val_lo
    sec
    sbc divisor
    sta val_lo
    lda val_hi
    sbc #0
    sta val_hi
    inc quot_lo
    bne @loop
    inc quot_hi
    jmp @loop
@done:
    rts
