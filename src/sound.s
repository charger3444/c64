; ====================================================================
; SID sound effects -- one-shot triggers using sustain=0 so the
; hardware envelope naturally decays to silence without needing a
; scheduled gate-off.
; ====================================================================

snd_jump:
    lda #0
    sta SID_V1CTRL
    lda #<$2800
    sta SID_V1FREQ
    lda #>$2800
    sta SID_V1FREQ+1
    lda #<$0800
    sta SID_V1PW
    lda #>$0800
    sta SID_V1PW+1
    lda #$09
    sta SID_V1AD
    lda #$00
    sta SID_V1SR
    lda #%01000001         ; pulse + gate
    sta SID_V1CTRL
    rts

snd_death:
    lda #0
    sta SID_V1CTRL
    lda #<$1800
    sta SID_V1FREQ
    lda #>$1800
    sta SID_V1FREQ+1
    lda #$08
    sta SID_V1AD
    lda #$06
    sta SID_V1SR
    lda #%10000001         ; noise + gate
    sta SID_V1CTRL
    rts

snd_crumble:
    lda #0
    sta SID_V1CTRL
    lda #<$3000
    sta SID_V1FREQ
    lda #>$3000
    sta SID_V1FREQ+1
    lda #$02
    sta SID_V1AD
    lda #$02
    sta SID_V1SR
    lda #%10000001         ; noise + gate
    sta SID_V1CTRL
    rts

note_freq_table:
    .word $0C00, $0F00, $1200, $1800

snd_note:                   ; A = index 0-3, a tiny fanfare arpeggio
    asl a
    tay
    lda #0
    sta SID_V1CTRL
    lda note_freq_table,y
    sta SID_V1FREQ
    lda note_freq_table+1,y
    sta SID_V1FREQ+1
    lda #$05
    sta SID_V1AD
    lda #$02
    sta SID_V1SR
    lda #%01000001         ; pulse + gate
    sta SID_V1CTRL
    rts
