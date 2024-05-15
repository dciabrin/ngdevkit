;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2024 Damien Ciabrini
;;; This file is part of ngdevkit
;;;
;;; ngdevkit is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU Lesser General Public License as
;;; published by the Free Software Foundation, either version 3 of the
;;; License, or (at your option) any later version.
;;;
;;; ngdevkit is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU Lesser General Public License for more details.
;;;
;;; You should have received a copy of the GNU Lesser General Public License
;;; along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.

;;; NSS opcode for SSG channels
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"

        
        .equ    NOTE_OFFSET,(state_mirrored_ssg_note-state_mirrored_ssg)
        .equ    NOTE_SEMITONE_OFFSET,(state_mirrored_ssg_note_semitone-state_mirrored_ssg)
        .equ    PROPS_OFFSET,(state_mirrored_ssg_props-state_mirrored_ssg)
        .equ    ENVELOPE_OFFSET,(state_mirrored_ssg_envelope-state_mirrored_ssg)
        .equ    WAVEFORM_OFFSET,(state_mirrored_ssg_waveform-state_mirrored_ssg)
        .equ    SSG_STATE_SIZE,(state_mirrored_ssg_end-state_mirrored_ssg)
        .equ    SSG_FX,(state_fx-state_mirrored_ssg)

        ;; this is to use IY as two IYH and IYL 8bits registers
        .macro dec_iyl
        .db     0xfd, 0x2d
        .endm

        .area  DATA

;;; SSG playback state tracker
;;; ------
        ;; This padding ensures the entire _state_ssg data sticks into
        ;; a single 256 byte boundary to make 16bit arithmetic faster
        .blkb   90

_state_ssg_start:

;;; context: current SSG channel for opcode actions
state_ssg_channel::
        .db     0

;;; address of the current instrument macro for all SSG channels
state_macro:
        .blkw   3
        
state_macro_pos:
        .blkw   3

state_macro_load_func:
        .blkw   3

;;; YM2610 mirrored state
;;; ------
;;; used to compute final register values to be loaded into the YM2610

;;; merged waveforms of all SSG channels for REG_SSG_ENABLE
state_mirrored_enabled:
        .db     0
        
;;; ssg mirrored state
state_mirrored_ssg:
        ;;; SSG A
state_fx:
        .db     0               ; must be the first field on the ssg state
;;; FX: slide
state_slide:
state_slide_speed: .db 0        ; number of increments per tick
state_slide_depth: .db 0        ; distance in semitones
state_slide_inc16: .dw 0        ; 1/8 semitone increment * speed
state_slide_pos16: .dw 0        ; slide pos
state_slide_end:   .db 0        ; end note (octave/semitone)
;;; FX: vibrato
state_vibrato:
state_vibrato_speed:
        .db     0               ; vibrato_speed
state_vibrato_depth:
        .db     0               ; vibrato_depth
state_vibrato_pos:
        .db     0               ; vibrato_pos
state_vibrato_prev:
        .dw     0               ; vibrato_prev
state_vibrato_next:
        .dw     0               ; vibrato_next
state_mirrored_ssg_note_semitone:
        .db     0               ; note (octave+semitone)
state_mirrored_ssg_note:
        .dw     0               ; note (fine+coarse)
state_mirrored_ssg_props:
state_mirrored_ssg_envelope:
        .db     0               ; envelope shape
        .db     0               ; vol envelope fine
        .db     0               ; vol envelope coarse
        .db     0               ; mode+volume
state_mirrored_ssg_waveform:
        .db     0               ; noise+tone (shifted per channel)
state_mirrored_ssg_end:
        ;;; SSG B
        .blkb   SSG_STATE_SIZE
        ;;; SSG C
        .blkb   SSG_STATE_SIZE

;;; note volume, to be substracted from instrument/macro volume
state_note_vol:
        .blkb   3

_state_ssg_end:

        .area  CODE

       
;;;  Reset SSG playback state.
;;;  Called before playing a stream
;;; ------
;;; [a modified - other registers saved]
init_nss_ssg_state_tracker::
        ld      hl, #_state_ssg_start
        ld      d, h
        ld      e, l
        inc     de
        ld      (hl), #0
        ld      bc, #_state_ssg_end-_state_ssg_start
        ldir
        ld      a, #0xff
        ld      (state_mirrored_enabled), a
        ld      bc, #macro_noop_load
        ld      (state_macro_load_func), bc
        ld      (state_macro_load_func+2), bc
        ld      (state_macro_load_func+4), bc
        ret


;;; 
;;; Macro instrument - internal functions
;;;

;;; eval_macro_step
;;; update the mirror state for a SSG channel based on
;;; the macro program configured for this channel
;;; ------
;;; IN:
;;; de: mirrored state of the current ssg channel
;;; hl: pointer to macro location for the current ssg channel
;;; OUT:
;;; de: address of the next macro step
;;;  a: 1: step updated the mirrored state
;;;     0: end of macro (no update)
;;; bc, de, hl modified
eval_macro_step::
        push    hl              ; macro location ptr
        ;; hl: (hl)
        ld      a, (hl)
        ld      c, a
        inc     hl
        ld      a, (hl)
        ld      h, a
        ld      l, c
        or      c
        jp      z, _end_macro
        ;; update mirrored state with macro values
        ld      a, (hl)
        inc     hl
_upd_macro:
        cp      a, #0xff
        jp      z, _end_upd_macro
        ;; de: next offset in mirrored state (8bit add)
        add     a, e
        ld      e, a
        ;; (de): (hl)
        ldi
        ld      a, (hl)
        inc     hl
        jp      _upd_macro
_end_upd_macro:
        ;; return the end address of the step
        ld      d, h
        ld      e, l
        ld      a, (hl)
        cp      a, #0xff
        jp      nz, _end_macro
        ;; end of macro, clear current macro (hl)
        pop     hl              ; macro location ptr
        xor     a
        ld      (hl), a
        inc     hl
        ld      (hl), a
        ;; a: macro cleared, but still load this step
        ld      a, #1
        ret
_end_macro:
        push    hl
        pop     bc
        pop     hl              ; macro location ptr
        ;; (hl): bc
        ld      a, c
        ld      (hl), a
        inc     hl
        ld      a, b
        ld      (hl), a
        ;; a: macro == 0, will drive the next load
        or      c
        ret        

        
;;; update_ssg_macros_and_effects
;;; ------
;;; For all ssg channels:
;;;  - run a single round of macro steps configured
;;;  - update the state of all enabled effects
;;; Meant to run once per tick
update_ssg_macros_and_effects::
        push    de
        ;; TODO should we consider IX and IY scratch registers?
        push    iy
        push    ix

        ;; macros expect the right ssg channel context,
        ;; so save the current channel context and loop
        ;; it artificially before calling the macro
        ld      a, (state_ssg_channel)
        push    af

        ;; update mirrored state of all SSG channels

        ;; state:
        ld      de, #state_mirrored_ssg_props ; ssg_a mirror state
        ld      hl, #state_macro_pos          ; ssg_a macro pos
        ld      ix, #state_macro_load_func    ; ssg_a load function
        xor     a
        ld      (state_ssg_channel), a        ; ssg ctx: ssg_a
        
        ld      iy, #3
_update_loop:
        push    hl              ; macro_pos
        push    de              ; state_mirrored
        push    de              ; state_mirrored
        call    eval_macro_step
        pop     hl              ; state_mirrored

        ;; skip loading for this channel if macro is finished
        cp      #0
        jr      nz, _prepare_ld_call
        inc     ix
        inc     ix
        jr      _post_call_load_func
_prepare_ld_call:
        ;; bc: load_func for this SSG channel
        ld      a, (ix)
        ld      c, a
        inc     ix
        ld      a, (ix)
        ld      b, a
        inc     ix

        ;; a: bitfield representation of current channel
        ld      a, (state_ssg_channel)
        sla     a
        jp      nz, _ld_call
        inc     a
_ld_call:

        ;; check whether the current channel is playing a note
        ld      d, a
        ld      a, (state_mirrored_enabled)
        xor     #0xff
        and     d
        jp      z, _post_effects
        ;; call the load_func (address: bc, args: hl)
        ld      de, #_post_call_load_func
        push    de
        push    bc
        ret
_post_call_load_func:
        ;; TODO: check whether effect should run before or after
        ;; macros. Also, the load function should be generic to
        ;; load note and volume even if only one of the macro or
        ;; the effect was in use.
        ;; hl: start of mirrored_ssg
        pop     hl              ; state_mirrored
        push    hl              ; state_mirrored

        ;; start of mirrored_ssg
        ld      a, l
        sub     #PROPS_OFFSET
        ld      l, a

        ;; configure
        ld      a, (hl)
_ssg_chk_fx_vibrato:
        bit     0, a
        jr      z, _ssg_chk_fx_slide
        call    eval_ssg_vibrato_step
        jr      _post_effects
_ssg_chk_fx_slide:
        bit     1, a
        jr      z, _post_effects
        call    eval_ssg_slide_step
_post_effects:
        ;; prepare to update the next channel
        ;; de: next state_mirrored
        pop     hl              ; state_mirrored
        ld      bc, #SSG_STATE_SIZE
        add     hl, bc
        ld      d, h
        ld      e, l
        ;; hl: next macro_pos
        pop     hl              ; macro_pos
        inc     hl
        inc     hl
        ;; ix: next load function is already set
        ;; next ssg context
        ld      a, (state_ssg_channel)
        inc     a
        ld      (state_ssg_channel), a

        dec_iyl
        jp      nz, _update_loop

        ;; restore the real ssg channel context
        pop     af
        ld      (state_ssg_channel), a

        pop     ix
        pop     iy
        pop     de
        ret



;;; macro_noop_load
;;; no-op function when no macro is configured for a SSG channel
;;; TODO is it still in use?
;;; ------
macro_noop_load:
        ret


 
;;; Mix requested volume with current note volume
;;; ------
;;; b : channel
;;; c : requested volume
ssg_mix_volume::
        push    hl
        ld      hl, #state_note_vol
        ;; hl + channel (8bit add)
        ld      a, b
        add     a, l
        ld      l, a

        ;; l: current note volume for channel
        ld      l, (hl)

        ;; mix volumes, min to 0
        ld      a, c
        sub     l
        jr      nc, _mix_set
        ld      a, #0
_mix_set:
        ld      c, a
        ld      a, b
        add     #REG_SSG_A_VOLUME
        ld      b, a
        call    ym2610_write_port_a
        pop     hl
        ret


;;; Configure the SSG channel based on a macro's data
;;; ------
;;; IN:
;;;   de: start offset in mirrored state data
;;; OUT
;;;   de: start offset for the current channel
;;; de, c modified
mirrored_ssg_for_channel:
        ;; c: current channel
        ld      a, (state_ssg_channel)
        ld      c, a
        ;; a: offset in bytes for current mirrored state
        xor     a
        bit     1, c
        jp      z, _m_post_double
        ld      a, #SSG_STATE_SIZE
        add     a
_m_post_double:
        bit     0, c
        jp      z, _m_post_plus
        add     #SSG_STATE_SIZE
_m_post_plus:
        ;; de + a (8bit add)
        add     a, e
        ld      e, a
        ret


;;; Set the right waveform value for the current SSG channel
;;; ------
;;; IN:
;;;   c: waveform
;;; OUT
;;;   c: shifted waveform for the current channel
;;; c modified
waveform_for_channel:
        ld      a, (state_ssg_channel)
        bit     0, a
        jp      z, _w_post_s0
        rlc     c
_w_post_s0:
        bit     1, a
        jp      z, _w_post_s1
        rlc     c
        rlc     c
_w_post_s1:
        ret


;;;  Reset SSG playback state.
;;;  Called before waiting for the next tick
;;; ------
;;; [a modified - other registers saved]
ssg_ctx_reset::
        ld      a, #0
        ld      (state_ssg_channel), a
        ret




;;; SSG NSS opcodes
;;; ------

;;; SSG_CTX_1
;;; Set the current SSG track to be SSG1 for the next SSG opcode processing
;;; ------
ssg_ctx_1::
        ;; set new current SSG channel
        ld      a, #0
        ld      (state_ssg_channel), a
        ld      a, #1
        ret


;;; SSG_CTX_2
;;; Set the current SSG track to be SSG3 for the next SSG opcode processing
;;; ------
ssg_ctx_2::
        ;; set new current SSG channel
        ld      a, #1
        ld      (state_ssg_channel), a
        ld      a, #1
        ret


;;; SSG_CTX_3
;;; Set the current SSG track to be SSG3 for the next SSG opcode processing
;;; ------
ssg_ctx_3::
        ;; set new current SSG channel
        ld      a, #2
        ld      (state_ssg_channel), a
        ld      a, #1
        ret


;;; SSG_MACRO
;;; Configure the SSG channel based on a macro's data
;;; ------
;;; [ hl ]: macro number
ssg_macro::
        push    de
        
        ;; a: macro
        ld      a, (hl)
        inc     hl

        push    hl

        ;; hl: macro address in ROM (hl:base + a:offset)
        ld      hl, (state_stream_instruments)
        sla     a
        ;; hl + a (8bit add)
        add     a, l
        ld      l, a
        adc     a, h
        sub     l
        ld      h, a

        ;; hl: macro definition in (hl)
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        ld      h, d
        ld      l, e
        
        ;; de: push function in ROM
        ;; TODO should be replaced by list of memory offsets to
        ;; load into ym2610 registers.
        ;; NOTE: the destination registers would be offset:
        ;;   - 0: for a SSG register shared across SSG channels
        ;;   - n: for targeting the (base+n'th) register (CHECK)
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        ;; hl (at this point): macro data

        ;; bc: address of current macro's data for current channel
        ld      bc, #state_macro
        ld      a, (state_ssg_channel)
        sla     a
        ;; bc + a (8bit add)
        add     a, c
        ld      c, a

        push    bc              ; save address of current macro's data
        ld      a, l
        ld      (bc), a
        inc     bc
        ld      a, h
        ld      (bc), a

        ;; configure push function for this channel
        ld      hl, #state_macro_load_func
        ld      a, (state_ssg_channel)
        sla     a
        ;; hl + a (8bit add)
        add     a, l
        ld      l, a
        ;; set push function
        ld      (hl), e
        inc     hl
        ld      (hl), d

        ;; bc: mirrored state's properties for current channel
        ld      de, #state_mirrored_ssg_props
        call    mirrored_ssg_for_channel
        ld      b, d
        ld      c, e

        ;; mirrored: update mirrored state with macro's properties
        pop     hl              ; (hl) = address of current macro's data
        push    bc              ; save mirrored_state's properties
        call    eval_macro_step
        ;; after this call, de points to the next macro step,
        ;; which is the part meant to be played for notes

        ;; load the envelope shape into ym2610, if it's present
        pop     hl              ; mirrored_state's properties
        ;; ld      bc, #ENVELOPE_OFFSET
        ;; add     hl, bc
        ;; a: mirrored envelope shape
        ld      a, (hl)
        bit     7, a
        jr      nz, _on_post_load
        ld      b, #REG_SSG_ENV_SHAPE
        ld      c, a
        call    ym2610_write_port_a
_on_post_load:

        pop     hl
        pop     de

        ld      a, #1
        ret


;;; Update the vibrato for the current FM channel and update the YM2610
;;; ------
;;; hl: mirrored state of the current fm channel
eval_ssg_vibrato_step::
        push    hl
        push    de
        push    bc

        ;; ix: state fx for current channel
        push    hl
        pop     ix

        call    vibrato_eval_step

        ;; ;; configure FM channel with new frequency
        ;; YM2610: load note
        ld      a, (state_ssg_channel)
        sla     a
        add     #REG_SSG_A_FINE_TUNE
        ld      b, a
        ld      c, l
        call    ym2610_write_port_a
        inc     b
        ld      c, h
        call    ym2610_write_port_a

        pop     bc
        pop     de
        pop     hl

        ret


;;; Setup SSG vibrato: position and increments
;;; ------
;;; ix : ssg state for channel
;;;      the note semitone must be already configured
ssg_vibrato_setup_increments::
        push    bc
        push    hl
        push    de

        ld      hl, #ssg_semitone_distance
        ld      l, NOTE_SEMITONE_OFFSET(ix)
        call    vibrato_setup_increments

        ;; de: vibrato prev increment, fixed point
        ld      VIBRATO_PREV(ix), e
        ld      VIBRATO_PREV+1(ix), d
        ;; hl: vibrato next increment, fixed point (negate)
        xor     a
        sub     l
        ld      l, a
        sbc     a, a
        sub     h
        ld      h, a
        ld      VIBRATO_NEXT(ix), l
        ld      VIBRATO_NEXT+1(ix), h

        pop     de
        pop     hl
        pop     bc
        ret


;;; Setup slide effect for the current FM channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
;;;    a  : slide direction: 0 == up, 1 == down
ssg_slide_common::
        push    bc
        push    de

        ;; de: FX for channel
        ld      b, a
        ld      de, #state_fx
        call    mirrored_ssg_for_channel
        ld      a, b

        ;; ix: SSG state for channel
        push    de
        pop     ix

        call    slide_init
        ld      e, NOTE_SEMITONE_OFFSET(ix)
        call    slide_setup_increments

        pop     de
        pop     bc

        ret



;;; Update the slide for the current channel
;;; Slide moves up or down by 1/8 of semitone increments * slide depth.
;;; ------
;;; hl: state for the current channel
eval_ssg_slide_step::
        push    hl
        push    de
        push    bc
        push    ix

        ;; update internal state for the next slide step
        call    eval_slide_step

        ;; effect still in progress?
        cp      a, #0
        jp      nz, _ssg_slide_add_intermediate
        ;; otherwise reset note state and load into YM2610
        ld      NOTE_SEMITONE_OFFSET(ix), d
        ;; hl: base note period for current semitone
        ld      hl, #ssg_tune
        ld      a, d
        sla     a
        ld      l, a
        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        ld      h, b
        ld      l, c
        ;; save new current note frequency
        ld      NOTE_OFFSET(ix), l
        ld      NOTE_OFFSET+1(ix), h
        jr      _ssg_slide_load_note

_ssg_slide_add_intermediate:
        ;; a: current semitone
        ld      a, SLIDE_POS16+1(ix)
        ;; b: next semitone distance from current note
        ld      hl, #ssg_semitone_distance
        ld      l, a
        ld      b, (hl)
        ;; c: SSG: intermediate frequency is negative
        ld      c, #1
        ;; e: intermediate semitone position (fractional part)
        ld      e, SLIDE_POS16(ix)
        ;; de: current intermediate frequency f_dist
        call    slide_intermediate_freq

        ;; hl: base note period for current semitone
        ld      hl, #ssg_tune
        ld      a, SLIDE_POS16+1(ix)
        sla     a
        ld      l, a
        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        ld      h, b
        ld      l, c

        ;; load new frequency into the YM2610
        ;; hl: semitone frequency + f_dist
        add     hl, de

_ssg_slide_load_note:
        ;; configure SSG channel with new note
        ld      a, (state_ssg_channel)
        sla     a
        ld      b, a
        ld      c, l
        call    ym2610_write_port_a
        inc     b
        ld      c, h
        call    ym2610_write_port_a

        pop     ix
        pop     bc
        pop     de
        pop     hl

        ret

        
;;; SSG_NOTE_OFF
;;; Release (stop) the note on the current SSG channel.
;;; ------
ssg_note_off::
        push    de
        push    bc
        push    hl        
        
        ;; de: mirrored state for current channel
        ld      de, #state_mirrored_ssg
        call    mirrored_ssg_for_channel

        ;; stop effects
        ld      a, #0
        ld      (de), a
        
        ;; de: mirrored waveform (8bit add)
        ld      a, #WAVEFORM_OFFSET
        add     a, e
        ld      e, a

        ;; c: disable mask (shifted for channel)
        ld      a, (de)
        ld      b, #0xff
        xor     b
        ld      c, a
        call    waveform_for_channel
        
        ;; stop channel
        ld      a, (state_mirrored_enabled)
        or      c
        ld      (state_mirrored_enabled), a
        ld      b, #REG_SSG_ENABLE
        ld      c, a
        call    ym2610_write_port_a

        ;; mute channel volume
        ld      a, (state_ssg_channel)
        add     #REG_SSG_A_VOLUME
        ld      b, a
        ld      c, #0
        call    ym2610_write_port_a

        ;; de: macro ptr for current channel (8bit add)
        ld      de, #state_macro_pos
        ld      a, (state_ssg_channel)
        sla     a
        add     a, e
        ld      e, a

        ;; remove current macro program
        xor     a
        ld      (de), a
        inc     de
        ld      (de), a
        
        pop     hl
        pop     bc        
        pop     de

        ;; ssg context will now target the next channel
        ld      a, (state_ssg_channel)
        inc     a
        ld      (state_ssg_channel), a

        ld      a, #1
        ret


;;; SSG_VOL
;;; Set the volume of the current SSG channel
;;; ------
;;; [ hl ]: volume level
ssg_vol::
        push    de

        ;; de: note volume for current channel (8bit add)
        ld      de, #state_note_vol
        ld      a, (state_ssg_channel)
        add     a, e
        ld      e, a

        ;; a: volume
        ld      a, (hl)
        inc     hl
        ld      b, a

        ;; (de): substracted mix volume (15-a)
        sub     a, #15
        neg
        ld      (de), a

        pop     de

        ld      a, #1
        ret
        
    
;;; SSG_NOTE_ON
;;; Emit a specific note (frequency) on a SSG channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
ssg_note_on::
        push    de
        push    bc

        ;; b: note (0xAB: A=octave B=semitone)
        ld      a, (hl)
        ld      b, a
        inc     hl

        push    hl

        ;; init current macro program

        ;; hl: macro for current channel (8bit add)
        ld      hl, #state_macro
        ld      a, (state_ssg_channel)
        sla     a
        add     a, l
        ld      l, a

        ;; de: macro ptr for current channel (8bit add)
        ;; +save ssg_macro
        ld      de, #state_macro_pos
        ld      a, (state_ssg_channel)
        sla     a
        add     a, e
        ld      e, a
        push    de
        
        ;; (de): start of macro program, from (hl)
        ld      a, b
        ld      bc, #2
        ldir
        ld      b, a
        
        ;; load ssg mirrored state

        ;; l: note
        ld      l, b

        ;; ;; de: mirrored note for current channel
        ld      de, #state_mirrored_ssg
        call    mirrored_ssg_for_channel

        ;; bc: mirrored_note_semitone, from mirrored_ssg (de)
        ld      b, d
        ld      c, e
        ld      a, #NOTE_SEMITONE_OFFSET
        add     c
        ld      c, a
        ;; store current octave/semitone
        ld      a, l
        ld      (bc), a

        ;; bc: mirrored_note (expected: from semitone)
        inc     c

        push    de
        pop     ix

        ;; check active effects
        ld      a, (de)
_on_check_vibrato:
        bit     0, a
        jr      z, _on_check_slide
        ;; reconfigure increments for current semitone
        call    ssg_vibrato_setup_increments
_on_check_slide:
        bit     1, a
        jr      z, _on_post_fx
        ;; reconfigure increments for current semitone
        ld      e, NOTE_SEMITONE_OFFSET(ix)
        call    slide_setup_increments
_on_post_fx:

        ;; de: ssg_note
        ld      d, b
        ld      e, c
        
        ;; mirrored: note frequency
        ld      a, l
        ld      hl, #ssg_tune
        sla     a
        ld      l, a
        ldi
        inc     bc
        ldi
        inc     bc

        ;; mirrored: update mirrored state with macro's properties
        ;; TODO: check the offset of eval macro and w.r.t generated macro
        pop     hl              ; ssg_macro
        push    bc              ; mirrored_note
        call    eval_macro_step
        
        ;; load mirrored state into the YM2610

        ;; YM2610: load note
        pop     hl              ; mirrored_note
        ld      a, (state_ssg_channel)
        sla     a
        add     #REG_SSG_A_FINE_TUNE
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_port_a
        inc     hl
        inc     b
        ld      c, (hl)
        call    ym2610_write_port_a

        ;; hl: go to ssg_props (expected: from ssg_note)
        inc     hl

        ;; YM2610: load properties (except waveform)
        push    hl              ; mirrored_props
        ;; de: pointer to push macro for current channel (8bit add)
        ld      de, #state_macro_load_func
        ld      a, (state_ssg_channel)
        sla     a
        add     a, e
        ld      e, a
        ;; call macro
        ld      bc, #_on_ret
        push    bc
        ld      a, (de)
        ld      c, a
        inc     de
        ld      a, (de)
        ld      b, a
        push    bc
        ret
_on_ret:

        ;; YM2610: load waveform
        pop     hl              ; mirrored_props
        ;; hl: mirrored_waveform (8bit add)
        ld      a, #(WAVEFORM_OFFSET-PROPS_OFFSET)
        add     a, l
        ld      l, a

        ;; c: waveform (shifted for channel)
        ld      c, (hl)
        call    waveform_for_channel

        ;; start note
        ld      a, (state_mirrored_enabled)
        and     c
        ld      (state_mirrored_enabled), a
        ld      b, #REG_SSG_ENABLE
        ld      c, a
        call    ym2610_write_port_a
        
        pop     hl
        pop     bc
        pop     de

        ;; ssg context will now target the next channel
        ld      a, (state_ssg_channel)
        inc     a
        ld      (state_ssg_channel), a

        ld      a, #1
        ret


;;; SSG_ENV_PERIOD
;;; Set the period of the SSG envelope generator
;;; ------
;;; [ hl ]: fine envelope period
;;; [hl+1]: coarse envelope period
ssg_env_period::
        push    bc

        ld      b, #REG_SSG_ENV_FINE_TUNE
        ld      a, (hl)
        inc     hl
        ld      c, a
        call    ym2610_write_port_a

        inc     b
        ld      a, (hl)
        inc     hl
        ld      c, a
        call    ym2610_write_port_a

        pop     bc

        ld      a, #1
        ret


;;; SSG_VIBRATO
;;; Enable vibrato for the current SSG channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
ssg_vibrato::
        push    bc
        push    de

        ;; de: fx for channel (expect: from mirrored_ssg)
        ld      de, #state_fx
        call    mirrored_ssg_for_channel

        ;; hl == 0 means disable vibrato
        ld      a, (hl)
        cp      #0
        jr      nz, _setup_vibrato
        push    hl              ; save NSS stream pos
        ;; disable vibrato fx
        ld      a, (de)
        res     0, a
        ld      (de), a
        ;; hl: address of original note frequency (8bit add)
        ld      h, d
        ld      a, #NOTE_OFFSET
        add     e
        ld      l, a
        ;; reconfigure the note into the YM2610
        ld      a, (state_ssg_channel)
        sla     a
        add     #REG_SSG_A_FINE_TUNE
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_port_a
        inc     hl
        inc     b
        ld      c, (hl)
        call    ym2610_write_port_a
        pop     hl              ; NSS stream pos
        jr      _post_setup

_setup_vibrato:
        ;; ix: ssg state for channel
        push    de
        pop     ix

        ;; vibrato fx on
        ld      a, SSG_FX(ix)
        ;; if vibrato was in use, keep the current vibrato pos
        bit     0, a
        jp      nz, _post_ssg_vibrato_pos
        ;; reset vibrato sine pos
        ld      VIBRATO_POS(ix), #0
_post_ssg_vibrato_pos:
        set     0, a
        ld      SSG_FX(ix), a

        ;; speed
        ld      a, (hl)
        rra
        rra
        rra
        rra
        and     #0xf
        ld      VIBRATO_SPEED(ix), a

        ;; depth, clamped to [1..16]
        ld      a, (hl)
        and     #0xf
        inc     a
        ld      VIBRATO_DEPTH(ix), a

        ;; increments for last configured note
        call    ssg_vibrato_setup_increments

_post_setup:
        inc     hl

        pop     de
        pop     bc

        ;; de: fx for channel (expect: from mirrored_ssg)
        ld      de, #state_fx
        call    mirrored_ssg_for_channel


        ld      a, #1
        ret


;;; SSG_SLIDE_UP
;;; Enable slide up effect for the current SSG channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
ssg_slide_up::
        ld      a, #0
        call    ssg_slide_common
        ld      a, #1
        ret


;;; SSG_SLIDE_DOWN
;;; Enable slide down effect for the current SSG channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
ssg_slide_down::
        ld      a, #1
        call    ssg_slide_common
        ld      a, #1
        ret
