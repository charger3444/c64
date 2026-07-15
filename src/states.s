; ====================================================================
; game states
; ====================================================================

; --------------------------------------------------------------------
st_title:
    lda state_timer
    beq @skipdraw
    jsr draw_title_screen
    lda #0
    sta state_timer
@skipdraw:
    jsr read_joystick
    lda fire_edge
    beq @done
    lda #0
    sta score_lo
    sta score_hi
    sta deaths_tot
    sta cur_level
    jsr load_level
    lda #ST_PLAY
    sta game_state
@done:
    rts

; --------------------------------------------------------------------
st_dead:
    inc state_timer
    lda state_timer
    cmp #1
    bne @nodraw
    jsr draw_dead_overlay
@nodraw:
    lda state_timer
    cmp #45
    bcc @done
    jsr respawn
    lda #ST_PLAY
    sta game_state
    lda #0
    sta state_timer
@done:
    rts

; --------------------------------------------------------------------
st_levelout:
    inc state_timer
    lda state_timer
    cmp #1
    bne @nodraw
    jsr draw_levelout_overlay
@nodraw:
    ; little 4-note fanfare arpeggio while the banner is up
    lda state_timer
    cmp #2
    beq @n0
    cmp #10
    beq @n1
    cmp #18
    beq @n2
    cmp #26
    beq @n3
    jmp @nosound
@n0:
    lda #0
    jsr snd_note
    jmp @nosound
@n1:
    lda #1
    jsr snd_note
    jmp @nosound
@n2:
    lda #2
    jsr snd_note
    jmp @nosound
@n3:
    lda #3
    jsr snd_note
@nosound:

    lda state_timer
    cmp #72
    bcc @done
    inc cur_level
    lda cur_level
    cmp #NUMLEVELS
    bcc @nextlevel
    jsr draw_blockdone_screen
    lda #ST_BLOCKDONE
    sta game_state
    lda #0
    sta state_timer
    jmp @done
@nextlevel:
    jsr load_level
    lda #ST_PLAY
    sta game_state
    lda #0
    sta state_timer
@done:
    rts

; --------------------------------------------------------------------
st_blockdone:
    jsr read_joystick
    lda fire_edge
    beq @done
    lda #1
    sta state_timer
    lda #ST_TITLE
    sta game_state
@done:
    rts

; --------------------------------------------------------------------
st_play:
    jsr read_joystick
    jsr play_physics
    jsr play_hazards
    jsr update_sprite
    jsr update_hud
    jsr update_flag_anim
    rts
