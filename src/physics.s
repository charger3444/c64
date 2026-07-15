; ====================================================================
; physics & collision  (fixed point, 7 fractional bits => *128)
; world coords match the original JS 1:1 (320x192, TILE=16)
; ====================================================================

; --------------------------------------------------------------------
; solid_at: A=col, X=row -> returns Z=1 (via zero flag) if NOT solid,
;           carry set in 'solid_result' (1/0)
; --------------------------------------------------------------------
solid_at:                       ; in: t0=col, t1=row  -> out: A=1 solid /0 not
    lda t0
    bmi @solid                  ; col<0 -> wall
    cmp #COLS
    bcs @solid                  ; col>=COLS -> wall
    lda t1
    bmi @notsolid                ; row<0 -> open sky above
    cmp #ROWS
    bcs @notsolid                 ; row>=ROWS -> open (fall zone)
    ; grid index = row*20+col
    jsr grid_index
    ldy #0
    lda (dstptr),y
    cmp #T_SOLID
    beq @solid
    cmp #T_FAKE
    beq @solid
    lda #0
    rts
@solid:
    lda #1
    rts
@notsolid:
    lda #0
    rts

; grid_index: t0=col,t1=row -> dstptr = &cur_grid[row*20+col]
grid_index:
    lda t1
    jsr mul_row20
    lda mul_lo
    clc
    adc t0
    sta t2
    lda mul_hi
    adc #0
    sta t3
    lda t2
    clc
    adc #<cur_grid
    sta dstptr
    lda t3
    adc #>cur_grid
    sta dstptr+1
    rts

; mul_row20: A=row(0-11) -> mul_lo/hi = row*20
mul_row20:
    sta t2
    lda #0
    sta mul_lo
    sta mul_hi
@loop:
    lda t2
    beq @done
    lda mul_lo
    clc
    adc #20
    sta mul_lo
    lda mul_hi
    adc #0
    sta mul_hi
    dec t2
    jmp @loop
@done:
    rts

; --------------------------------------------------------------------
; fixed_to_pixel: in_lo/in_hi -> pix_lo/pix_hi  (pix = in >> 7, 9 bit)
; --------------------------------------------------------------------
fixed_to_pixel_x:
    lda px_lo
    sta t0
    lda px_hi
    sta t1
    jmp fixed_to_pixel_do
fixed_to_pixel_y:
    lda py_lo
    sta t0
    lda py_hi
    sta t1
fixed_to_pixel_do:
    lda t0
    asl a
    lda t1
    rol a
    sta pix_lo
    lda #0
    rol a
    sta pix_hi
    rts

; tile_from_pixel: pix_lo/pix_hi (9-bit) -> A = tile index
tile_from_pixel:
    lda pix_lo
    lsr a
    lsr a
    lsr a
    lsr a
    ldx pix_hi
    beq @done
    clc
    adc #16
@done:
    rts

; --------------------------------------------------------------------
; compute the 4 tile bounds (tc0,tc1,tr0,tr1) for the player's AABB at
; the CURRENT (px,py) position -- used for ground/fake-floor checks.
; --------------------------------------------------------------------
calc_bounds_current:
    jsr fixed_to_pixel_x
    jsr tile_from_pixel
    sta tc0
    lda pix_lo
    clc
    adc #(PLW-1)
    sta pix_lo
    bcc @nc1
    inc pix_hi
@nc1:
    jsr tile_from_pixel
    sta tc1

    jsr fixed_to_pixel_y
    jsr tile_from_pixel
    sta tr0
    lda pix_lo
    clc
    adc #(PLH-1)
    sta pix_lo
    bcc @nc2
    inc pix_hi
@nc2:
    jsr tile_from_pixel
    sta tr1
    rts

; --------------------------------------------------------------------
; rect_solid: uses tc0/tc1/tr0/tr1 -> A=1 if any of the 4 corner tiles
; is solid
; --------------------------------------------------------------------
rect_solid:
    lda tc0
    sta t0
    lda tr0
    sta t1
    jsr solid_at
    cmp #1
    beq @yes
    lda tc1
    sta t0
    lda tr0
    sta t1
    jsr solid_at
    cmp #1
    beq @yes
    lda tc0
    sta t0
    lda tr1
    sta t1
    jsr solid_at
    cmp #1
    beq @yes
    lda tc1
    sta t0
    lda tr1
    sta t1
    jsr solid_at
    cmp #1
    beq @yes
    lda #0
    rts
@yes:
    lda #1
    rts

; ====================================================================
; play_physics -- called once per frame while state==PLAY
; ====================================================================
play_physics:
    inc clock_lo
    bne @nowrap
    inc clock_hi
@nowrap:
    inc anim_ctr

    ; ---------------- horizontal ----------------
    lda joy_right
    beq @noright
    lda joy_left
    bne @friction        ; both held -> cancel out, fall through to friction
    lda #0
    sta face
    jsr accel_pos
    jmp @clampx
@noright:
    lda joy_left
    beq @maybefriction
    lda #1
    sta face
    jsr accel_neg
    jmp @clampx
@maybefriction:
@friction:
    lda on_ground
    beq @clampx
    jsr apply_friction
@clampx:
    jsr clamp_vx

    ; ---------------- jump buffer / coyote ----------------
    lda fire_edge
    beq @nobuf
    lda #BUFFER_FRAMES
    sta buffer
@nobuf:
    lda buffer
    beq @nobufdec
    dec buffer
@nobufdec:
    lda coyote
    beq @nocoydec
    dec coyote
@nocoydec:
    lda buffer
    beq @nojump
    lda coyote
    beq @nojump
    SETW vy_lo, FP_JUMPV
    lda #0
    sta coyote
    sta buffer
    sta on_ground
    jsr snd_jump
@nojump:

    ; ---------------- variable jump height ----------------
    lda joy_fire
    bne @noclampcut
    jsr clamp_jumpcut
@noclampcut:

    ; ---------------- gravity ----------------
    lda vy_lo
    clc
    adc #<FP_GRAV
    sta vy_lo
    lda vy_hi
    adc #>FP_GRAV
    sta vy_hi
    jsr clamp_maxfall

    ; ---------------- move ----------------
    jsr move_x
    jsr move_y
    rts

; --------------------------------------------------------------------
accel_pos:
    lda on_ground
    beq @air
    lda vx_lo
    clc
    adc #<FP_ACC_G
    sta vx_lo
    lda vx_hi
    adc #>FP_ACC_G
    sta vx_hi
    rts
@air:
    lda vx_lo
    clc
    adc #<FP_ACC_A
    sta vx_lo
    lda vx_hi
    adc #>FP_ACC_A
    sta vx_hi
    rts

accel_neg:
    lda on_ground
    beq @air
    lda vx_lo
    sec
    sbc #<FP_ACC_G
    sta vx_lo
    lda vx_hi
    sbc #>FP_ACC_G
    sta vx_hi
    rts
@air:
    lda vx_lo
    sec
    sbc #<FP_ACC_A
    sta vx_lo
    lda vx_hi
    sbc #>FP_ACC_A
    sta vx_hi
    rts

; --------------------------------------------------------------------
apply_friction:
    lda vx_lo
    ora vx_hi
    beq @done
    lda vx_hi
    bmi @neg
    lda vx_lo
    sec
    sbc #<FP_FRIC
    sta vx_lo
    lda vx_hi
    sbc #>FP_FRIC
    sta vx_hi
    bpl @done
    lda #0
    sta vx_lo
    sta vx_hi
    jmp @done
@neg:
    lda vx_lo
    clc
    adc #<FP_FRIC
    sta vx_lo
    lda vx_hi
    adc #>FP_FRIC
    sta vx_hi
    bmi @done
    lda #0
    sta vx_lo
    sta vx_hi
@done:
    rts

; --------------------------------------------------------------------
clamp_vx:
    lda vx_hi
    bmi @negside
    lda vx_hi
    cmp #>FP_MOVE
    bcc @done
    bne @poscl
    lda vx_lo
    cmp #<FP_MOVE
    bcc @done
@poscl:
    SETW vx_lo, FP_MOVE
    rts
@negside:
    lda vx_hi
    cmp #>FP_MOVE_NEG
    bcc @negcl
    bne @done
    lda vx_lo
    cmp #<FP_MOVE_NEG
    bcc @negcl
    jmp @done
@negcl:
    SETW vx_lo, FP_MOVE_NEG
@done:
    rts

; --------------------------------------------------------------------
clamp_maxfall:
    lda vy_hi
    bmi @done
    lda vy_hi
    cmp #>FP_MAXFALL
    bcc @done
    bne @cl
    lda vy_lo
    cmp #<FP_MAXFALL
    bcc @done
@cl:
    SETW vy_lo, FP_MAXFALL
@done:
    rts

clamp_jumpcut:
    lda vy_hi
    bpl @done
    lda vy_hi
    cmp #>FP_JUMPCUT
    bcc @cl
    bne @done
    lda vy_lo
    cmp #<FP_JUMPCUT
    bcc @cl
    jmp @done
@cl:
    SETW vy_lo, FP_JUMPCUT
@done:
    rts

; --------------------------------------------------------------------
; move_x: apply vx to px, snap to tile boundary on collision
; --------------------------------------------------------------------
move_x:
    lda vx_lo
    ora vx_hi
    beq @skip

    lda px_lo
    clc
    adc vx_lo
    sta t2                    ; new x lo (temp)
    lda px_hi
    adc vx_hi
    sta t3                    ; new x hi (temp)

    ; compute tile bounds using the trial X and CURRENT Y
    lda t2
    sta px_lo
    lda t3
    sta px_hi
    jsr calc_bounds_current
    jsr rect_solid
    cmp #1
    beq @blocked

    ; not blocked -- already committed above (px already updated)
    jmp @skip

@blocked:
    lda vx_hi
    bmi @movingleft
    ; moving right: clamp so right edge sits at tc1*16 - 1
    lda tc1
    jsr tiles_to_pixel16      ; pix_lo/pix_hi = tc1*16
    lda pix_lo
    sec
    sbc #PLW
    sta pix_lo
    bcs @rok
    dec pix_hi
@rok:
    jsr pixel_to_fixed_x
    jmp @zerovx
@movingleft:
    lda tc0
    clc
    adc #1
    jsr tiles_to_pixel16      ; pix = (tc0+1)*16
    jsr pixel_to_fixed_x
@zerovx:
    lda #0
    sta vx_lo
    sta vx_hi
@skip:
    rts

; --------------------------------------------------------------------
; move_y: apply vy to py, snap to tile boundary; updates on_ground
; --------------------------------------------------------------------
move_y:
    lda vy_lo
    ora vy_hi
    beq @skipmove

    lda py_lo
    clc
    adc vy_lo
    sta t2
    lda py_hi
    adc vy_hi
    sta t3

    lda t2
    sta py_lo
    lda t3
    sta py_hi
    jsr calc_bounds_current
    jsr rect_solid
    cmp #1
    beq @blocked
    jmp @notblocked

@blocked:
    lda vy_hi
    bmi @movingup
    ; falling: land on tr1
    lda tr1
    jsr tiles_to_pixel16
    lda pix_lo
    sec
    sbc #PLH
    sta pix_lo
    bcs @dok
    dec pix_hi
@dok:
    jsr pixel_to_fixed_y
    lda #1
    sta on_ground
    lda #COYOTE_FRAMES
    sta coyote
    jmp @zerovy
@movingup:
    lda tr0
    clc
    adc #1
    jsr tiles_to_pixel16
    jsr pixel_to_fixed_y
@zerovy:
    lda #0
    sta vy_lo
    sta vy_hi
    jmp @afterground

@notblocked:
    lda on_ground
    beq @afterground
    lda #0
    sta on_ground
    lda #COYOTE_FRAMES
    sta coyote
@afterground:
@skipmove:
    rts

; --------------------------------------------------------------------
; tiles_to_pixel16: A=tile index -> pix_lo/pix_hi = tile*16 (9-bit)
; --------------------------------------------------------------------
tiles_to_pixel16:
    asl a                 ; *16 = 4 left shifts, tracking overflow into pix_hi
    sta t0
    lda #0
    rol a
    sta t1
    asl t0
    rol t1
    asl t0
    rol t1
    asl t0
    rol t1
    lda t0
    sta pix_lo
    lda t1
    sta pix_hi
    rts

; pixel_to_fixed_x: pix_lo/pix_hi (9-bit pixel) -> px_lo/px_hi (fixed*128)
pixel_to_fixed_x:
    lda pix_lo
    sta t0
    lda pix_hi
    sta t1
    jsr pixel9_to_fixed
    lda t0
    sta px_lo
    lda t1
    sta px_hi
    rts

pixel_to_fixed_y:
    lda pix_lo
    sta t0
    lda pix_hi
    sta t1
    jsr pixel9_to_fixed
    lda t0
    sta py_lo
    lda t1
    sta py_hi
    rts

; pixel9_to_fixed: t0/t1 (9-bit pixel) -> t0/t1 (16-bit fixed, *128)
pixel9_to_fixed:
    asl t0
    rol t1
    asl t0
    rol t1
    asl t0
    rol t1
    asl t0
    rol t1
    asl t0
    rol t1
    asl t0
    rol t1
    asl t0
    rol t1
    rts
