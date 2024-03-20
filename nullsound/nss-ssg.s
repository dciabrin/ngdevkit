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

        
        .equ    NOTE_OFFSET,(state_mirrored_ssg_note-state_mirrored_ssg)
        .equ    PROPS_OFFSET,(state_mirrored_ssg_props-state_mirrored_ssg)
        .equ    WAVEFORM_OFFSET,(state_mirrored_ssg_waveform-state_mirrored_ssg)
        .equ    SSG_STATE_SIZE,(state_mirrored_ssg_end-state_mirrored_ssg)

        ;; this is to use IY as two IYH and IYL 8bits registers
        .macro dec_iyl
        .db     0xfd, 0x2d
        .endm

        .area  DATA

;;; SSG playback state tracker
;;; ------
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
state_mirrored_ssg_note:
        .dw     0               ; note (fine+coarse)
state_mirrored_ssg_props:
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
;;; [ de ]: mirrored state of the current ssg channel
;;; [ hl ]: pointer to macro location for the current ssg channel
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
        ;; de: next offset in mirrored state
        add     e
        ld      e, a
        ;; (de): (hl)
        ldi
        ld      a, (hl)
        inc     hl
        jp      _upd_macro
_end_upd_macro:
        ld      a, (hl)
        cp      a, #0xff
        jp      nz, _end_macro
        ;; end of macro, clear current macro (hl)
        pop     hl              ; macro location ptr
        xor     a
        ld      (hl), a
        inc     hl
        ld      (hl), a
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
        ret        

        
;;; update_ssg_macros
;;; run a single round of macro steps configured for
;;; all the SSG channels. Meant to run once per tick
update_ssg_macros::
        push    de
        ;; TODO can we use another register?
        push    iy

        ;; update mirrored state of all SSG channels
        ld      de, #state_mirrored_ssg_props
        ld      hl, #state_macro_pos
        ld      iy, #3
_upd_mirrored:
        push    hl              ; macro_pos
        push    de              ; state_mirrored
        call    eval_macro_step
        pop     hl              ; state_mirrored
        ld      bc, #SSG_STATE_SIZE
        add     hl, bc
        ld      d, h
        ld      e, l
        pop     hl              ; macro_pos
        inc     hl
        inc     hl
        dec_iyl
        jp      nz, _upd_mirrored
                
        ;; macros expect the right ssg channel context,
        ;; so save the current channel context and loop
        ;; it artificially before calling the macro
        ld      a, (state_ssg_channel)
        push    af
        xor     a
        ld      (state_ssg_channel), a
        
        ;; load mirrored state (except waveform) of all SSG channels
        ld      hl, #state_mirrored_ssg_props
        ld      de, #state_macro_load_func
        ld      iy, #3
_ld_mirrored:
        push    hl              ; state_mirrored
        ;; bc: load_func for this SSG channel
        ld      a, (de)
        ld      c, a
        inc     de
        ld      a, (de)
        ld      b, a
        inc     de
        push    de              ; pointer to next load_func
        ;; a: number -> bitfield
        ld      a, (state_ssg_channel)
        sla     a
        jp      nz, _ld_call
        inc     a
_ld_call:
        ;; check whether the current channel is active
        ld      d, a
        ld      a, (state_mirrored_enabled)
        xor     #0xff
        and     d
        jp      z, _ld_call_ret
        ;; call the load_func
        ld      de, #_ld_call_ret
        push    de
        push    bc
        ret
_ld_call_ret:
        ;; fake the current ssg context for the macro
        ld      a, (state_ssg_channel)
        inc     a
        ld      (state_ssg_channel), a
        pop     de              ; pointer to next load func
        pop     hl              ; state_mirrored
        ld      bc, #SSG_STATE_SIZE
        add     hl, bc
        dec_iyl
        jp      nz, _ld_mirrored

        ;; restore the real ssg channel context
        pop     af
        ld      (state_ssg_channel), a

        pop     iy
        pop     de
        ret

;;; macro_noop_load
;;; no-op function when no macro is configured for a SSG channel
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
        adc     a, h
        sub     l
        ld      h, a

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
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl        
        push    hl              ; save macro_data

        ;; configure push function for this channel
        ld      hl, #state_macro_load_func
        ld      a, (state_ssg_channel)
        sla     a
        ;; hl + a (8bit add)
        add     a, l
        ld      l, a
        adc     a, h
        sub     l
        ld      h, a
        ;; set push function 
        ld      (hl), e
        inc     hl
        ld      (hl), d
        
        ;; de: macro data in ROM
        pop     de
        
        ;; configure macro data for this channel
        ld      hl, #state_macro
        ld      a, (state_ssg_channel)
        sla     a
        ;; hl + a (8bit add)
        add     a, l
        ld      l, a
        adc     a, h
        sub     l
        ld      h, a
        ;; set macro data 
        ld      (hl), e
        inc     hl
        ld      (hl), d

        pop     hl
        pop     de

        ld      a, #1
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
        ;; c: current channel
        ld      a, (state_ssg_channel)
        ld      c, a
        ;; a: offset in bytes for current mirrored state
        xor     a
        bit     1, c
        jp      z, _off_post_double
        ld      a, #SSG_STATE_SIZE
        add     a
_off_post_double:
        bit     0, c
        jp      z, _off_post_plus
        add     #SSG_STATE_SIZE
_off_post_plus:
        ;; de + a (8bit add)
        add     a, e
        ld      e, a
        adc     a, d
        sub     e
        ld      d, a
        
        ;; de: mirrored waveform
        ld      a, #WAVEFORM_OFFSET
        add     a, e
        ld      e, a
        adc     a, d
        sub     e
        ld      d, a

        ;; c: disable mask (shifted for channel)
        ld      a, (de)
        ld      b, #0xff
        xor     b
        ld      c, a
        ld      a, (state_ssg_channel)
        bit     0, a
        jp      z, _off_post_s0
        rlc     c
_off_post_s0:
        bit     1, a
        jp      z, _off_post_s1
        rlc     c
        rlc     c
_off_post_s1:
        
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
        adc     a, d
        sub     e
        ld      d, a

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
        adc     a, d
        sub     e
        ld      d, a

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
        adc     a, h
        sub     l
        ld      h, a

        ;; de: macro ptr for current channel (8bit add)
        ;; +save ssg_macro
        ld      de, #state_macro_pos
        ld      a, (state_ssg_channel)
        sla     a
        add     a, e
        ld      e, a
        adc     a, d
        sub     e
        ld      d, a
        push    de
        
        ;; (de): start of macro program
        ld      a, b
        ld      bc, #2
        ldir
        ld      b, a
        
        ;; load ssg mirrored state
        
        ;; de: mirrored state for current channel
        ld      de, #state_mirrored_ssg
        ;; c: current channel
        ld      a, (state_ssg_channel)
        ld      c, a
        ;; a: offset in bytes for current mirrored state
        xor     a
        bit     1, c
        jp      z, _on_post_double
        ld      a, #SSG_STATE_SIZE
        add     a
_on_post_double:
        bit     0, c
        jp      z, _on_post_plus
        add     #SSG_STATE_SIZE
_on_post_plus:
        ;; de + a (8bit add)
        add     a, e
        ld      e, a
        adc     a, d
        sub     e
        ld      d, a

        ;; l: note
        ld      l, b
        
        ;; bc: mirrored_state (de+a)
        ld      b, d
        ld      c, e
        
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
        pop     hl              ; ssg_macro
        push    bc              ; mirrored_state
        call    eval_macro_step
        ;; nop
        ;; nop
        ;; nop
        
        ;; load mirrored state into the YM2610

        ;; YM2610: load note
        pop     hl              ; mirrored_state
        ld      a, (state_ssg_channel)
        sla     a
        add     #REG_SSG_A_FINE_TUNE
        ld      b, a
        ld      c, (hl)
        inc     hl
        call    ym2610_write_port_a
        inc     b
        ld      c, (hl)
        inc     hl
        call    ym2610_write_port_a

        ;; YM2610: load properties (except waveform)
        push    hl              ; mirrored_props
        ;; de: pointer to push macro for current channel (8bit add)
        ld      de, #state_macro_load_func
        ld      a, (state_ssg_channel)
        sla     a
        add     a, e
        ld      e, a
        adc     a, d
        sub     e
        ld      d, a
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
        adc     a, h
        sub     l
        ld      h, a

        ;; b: waveform (shifted for channel)
        ld      b, (hl)
        ld      a, (state_ssg_channel)
        bit     0, a
        jp      z, _on_post_s0
        rlc     b
_on_post_s0:
        bit     1, a
        jp      z, _on_post_s1
        rlc     b
        rlc     b
_on_post_s1:
        ;; start note
        ld      a, (state_mirrored_enabled)
        and     b
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

