;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2023 Damien Ciabrini
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

;;; The following driver is based on doc found on neogeodev wiki
;;; https://wiki.neogeodev.org/index.php?title=68k/Z80_communication

        .module nullsound

        .include "ym2610.inc"

        .equ    CH_STREAM_SIZE,(state_ch_stream_end-state_ch_stream)
        .equ    OPCODE_NSS_NOP, 8

;;;
;;; Sound stream state tracker
;;; -------------------
;;;  . next sound opcode to be processed from the stream
;;;  . current volume per channel type (FM, ADPCM...)
;;;  . current detune per channel type (FM, ADPCM...)
;;;
        .area  DATA

;;; stream playback running
state_stream_in_use::           .blkb   1

;;; NSS instrument data used by this stream
state_stream_instruments::      .blkb   2

;;; number of stream to play
state_streams::                 .blkb   1
        
;;; per-channel context switch function
state_ch_ctx_switch::           .blkb   14

;;; per-channel wait state
state_ch_wait_ticks::           .blkb   14

;;; per-channel stream state (6 bytes)
state_ch_stream:
state_ch_stream_saved_pos::     .blkb   2
state_ch_stream_start::         .blkb   2
state_ch_stream_pos::           .blkb   2
state_ch_stream_end:
        .blkb   CH_STREAM_SIZE*13

;;; current addresses/indices
state_current_ch_ctx::          .blkb   2
state_current_ch_wait_ticks::   .blkb   2
state_current_ch_stream::       .blkb   2
state_stream_idx::              .blkb   1
state_pending_timer_wait::      .blkb   1

        ;; FIXME: temporary padding to ensures the next data sticks into
        ;; a single 256 byte boundary to make 16bit arithmetic faster
        .blkb   70

        
        .area  CODE


init_stream_state_tracker::
        ld      a, #0
        ld      (state_stream_in_use), a
        ld      bc, #0
        ld      (state_stream_instruments), bc
        ret


;;; substract the currently recorded tick events to every stream's
;;; 'wait ticks' information.
;;; In the process count the remaining ticks for each stream and
;;; recall the smallest one (non zero). This will be used as the
;;; number of ticks to wait before the next opcode processing.
;;; ------
;;; [a modified - other registers saved]
sub_ticks::
        push    de
        push    bc
        push    hl
        ;; we know we passed at least state_timer_int_b_wait
        ;; ticks, substract them from all the streams' wait_ticks
        ;; b: ticks reached
        ld      a, (state_timer_int_b_wait)
        ld      b, a
        ;; b: min ticks remaining after sub
        ld      d, a
        ;; c: streams playing
        ld      a, (state_streams)
        ld      c, a
        ;; hl: streams wait state
        ld      hl, #state_ch_wait_ticks
_tick_sub_loop:
        ;; a new wait tick for current channel
        ld      a, (hl)
        sub     b
        ld      (hl), a
        ;; if the remainder is positive, recall min(smallest_wait, channel_wait)
        jr      z, _post_sub_min
        cp      d
        jr      nc, _post_sub_min
        ld      d, a
_post_sub_min:
        inc     hl
        dec     c
        jr      nz, _tick_sub_loop
        ;; record the next minimum number of ticks to reach
        ;; before at least one channel can evaluate opcodes
        ld      a, d
        ld      (state_pending_timer_wait), a
        pop     hl
        pop     bc
        pop     de
        ret


;;; process opcodes for all the streams that are not waiting for ticks
;;; ------
;;; [all registers modified]
process_streams_opcodes::
        ld      a, #0
        ld      (state_stream_idx), a
        ld      bc, #state_ch_wait_ticks
        ld      (state_current_ch_wait_ticks), bc
        ld      bc, #state_ch_ctx_switch
        ld      (state_current_ch_ctx), bc
        ld      bc, #state_ch_stream
        ld      (state_current_ch_stream), bc
_loop_chs:
        ;; [de]: wait ticks for current stream
        ld      de, (state_current_ch_wait_ticks)
        ld      a, (de)        
        ;; loop to next stream if this one is not ready
        ;; to process more opcodes
        cp      #0
        jp      nz, _post_ch_process
        ;; otherwise setup stream context
        ;; (by processing the current ctx opcode)
        ld      hl, (state_current_ch_ctx)
        call    process_nss_opcode
        
        ;; process the stream's next opcodes
        
        ;; hl: current stream's position (8bit add)
        ld      ix, (state_current_ch_stream)
        ld      l, 4(ix)
        ld      h, 5(ix)
_loop_opcode:
        call    process_nss_opcode
        or      a
        jp      nz, _loop_opcode
        ;; no more opcodes can be processed, save stream's new pos
        ld      ix, (state_current_ch_stream)
        ld      4(ix), l
        ld      5(ix), h
_post_ch_process:
        ld      a, (state_streams)
        ld      b, a
        ld      a, (state_stream_idx)
        inc     a
        cp      b
        jr      nc, _end_process
        ld      (state_stream_idx), a
        ld      hl, (state_current_ch_wait_ticks)
        inc     hl
        ld      (state_current_ch_wait_ticks), hl
        ld      hl, (state_current_ch_ctx)
        inc     hl
        ld      (state_current_ch_ctx), hl
        ld      hl, (state_current_ch_stream)
        ld      bc, #6
        add     hl, bc
        ld      (state_current_ch_stream), hl
        jr      _loop_chs
_end_process:
        ld      a, (state_pending_timer_wait)
        cp      #0
        jr      z, _ret_from_process
        ;; register the timer wait now that all streams have been processed
        ld      (state_timer_int_b_wait), a
        xor     a
        ld      (state_timer_int_b_reached), a
_ret_from_process:
        ret
        

;;; Evaluate the opcodes from the current nullsound stream,
;;; until an opcode must yield the execution (end of stream, timer wait)
;;; the current stream and current opcode pointer are in memory
;;; ------
;;; [a modified - other registers saved]
update_stream_state_tracker::
        push    hl
        push    bc
        ;; check whether stream is in use
        ld      a, (state_stream_in_use)
        or      a
        jp      z, _no_more_processing
        ;; check whether one stream is ready for processing more nss opcodes
        ld      a, (state_timer_int_b_wait)
        ld      b, a
        ld      a, (state_timer_int_b_count)
        cp      b
        ;; if we can't, check whether we have macros or effects to process
        jp      c, _check_update_macros_and_effects
        call    sub_ticks
        ld      a, (state_timer_int_b_wait)
        ld      b, a
        ld      a, (state_timer_int_b_count)
        sub     b
        ld      (state_timer_int_b_count), a        
        call    process_streams_opcodes        
_no_more_processing:
        pop     bc
        pop     hl
        ret
_check_update_macros_and_effects:
        ld      a, (state_timer_int_b_reached)
        cp      a, #1
        jp      nz, _no_macro_update
        call    update_fm_effects
        call    update_ssg_macros_and_effects
        ld      a, #0
        ld      (state_timer_int_b_reached), a
_no_macro_update:
        pop     bc
        pop     hl
        ret


;;; Initialize subsystems' state trackers and stream wait state
;;; ------
snd_stream_reset_state::
        ;; reset state trackers
        call    init_nss_fm_state_tracker
        call    init_nss_ssg_state_tracker
        call    init_nss_adpcm_state_tracker
        ld      a, #1
        ld      (state_stream_in_use), a

        ;; init stream wait tracker
        ld      a, #0
        ld      hl, #state_ch_wait_ticks
        ld      (hl), a
        ld      b, a
        ld      a, (state_streams)
        cp      #0
        jr      z, _post_memset_wait_ticks
        ld      c, a
        ld      d, h
        ld      e, l
        inc     de
        ldir
_post_memset_wait_ticks:
        ret


;;; Play music or sfx from a pre-compiled stream of sound opcodes
;;; the data is encoded in the nullsound stream format
;;; ------
;;; bc: nullsound instruments
;;; de: nullsound stream description
;;; [a modified - other registers saved]
snd_stream_play::
        ;; compact marker: configure playback for a compact NSS streams
        ld      a, (de)
        cp      #0xff
        jp      z, snd_multi_stream_play

        ;; else prepare stream playback for a single stream
        call    snd_stream_stop

        ;; setup current instruments
        ld      (state_stream_instruments), bc

        ;; init stream state
        ld      (state_ch_stream_start), de
        ld      (state_ch_stream_pos), de

        ;; setup playback for a single NSS steam
        ld      a, #1
        ld      (state_streams), a

        ;; for single NSS stream, ctx switch table is not used (nop),
        ;; context opcodes are part of the stream itself
        ld      hl, #state_ch_ctx_switch
        ld      a, #OPCODE_NSS_NOP
        ld      (hl), a        

        ;; reset state trackers
        call    snd_stream_reset_state

        ;; start stream playback, it will get preempted
        ;; as soon as a wait opcode shows up in the stream
        call    update_stream_state_tracker
        ret


;;; Play music or sfx from a pre-compiled list of precompile NSS opcodes
;;; the data is encoded as multi-stream compact NSS representation
;;; ------
;;; bc: nullsound instruments
;;; de: nullsound streams description
;;; [a modified - other registers saved]
snd_multi_stream_play::
        call    snd_stream_stop
        push    de
        pop     ix
        inc     ix

        ;; setup current instruments
        ld      (state_stream_instruments), bc

        ;; a: number of streams
        ld      a, (ix)
        ld      (state_streams), a

        ;; init ctx switch table
        ld      b, #0
        ld      c, a
        inc     ix
        push    ix
        pop     hl
        ld      de, #state_ch_ctx_switch
        ldir

        ;; init streams state
        ld      ix, #state_ch_stream
        ld      de, #6
        ld      a, (state_streams)
        ld      c, a
_stream_play_init_loop:
        ld      a, (hl)
        ld      2(ix), a
        ld      4(ix), a
        inc     hl
        ld      a, (hl)
        ld      3(ix), a
        ld      5(ix), a
        inc     hl
        add     ix, de
        dec     c
        jr      nz, _stream_play_init_loop
        push    hl              ; initial tempo (timer B)

        ;; reset state trackers
        call    snd_stream_reset_state
        
        ;; configure timer before starting the stream
        pop     hl              ; initial tempo (timer B)
        call    run_timer_b

        ;; start stream playback, it will get preempted
        ;; as soon as a wait opcode shows up in the stream
        call    update_stream_state_tracker
        ret


;;; Stop music or sfx stream playback
;;; ------
;;; [a modified - other registers saved]
snd_stream_stop::
        ;; force-stop any active channels, disable timers
        call    ym2610_reset
        ;; clear playback state tracker
        ld      a, #0
        ld      (state_stream_in_use), a
        ld      (state_timer_int_b_count), a
        ld      (state_timer_int_b_wait), a
        ret


;;; NSS opcodes lookup table
;;; ------
;;; The functions below all follow the same interface
;;; bc [IN]: arguments of the current NSS opcode in the stream
;;;          bc gets incremented to all the parse arguments, and
;;;          on function exit, bc must point to the next NSS opcode
;;;          in the stream
;;; a [OUT]: 1: processing of the next opcode can continue
;;;          0: processing must stop (the playback must wait for
;;;             the timer for sync, or the stream is finished)
;;;
;;; [a and bc modified - other registers must be saved]
nss_opcodes:
        .dw     write_port_a
        .dw     write_port_b
        .dw     nss_jmp
        .dw     nss_end
        .dw     run_timer_b
        .dw     wait_int_b
        .dw     nss_call
        .dw     nss_ret
        .dw     nss_nop
        .dw     adpcm_a_instrument_ext
        .dw     adpcm_a_on_ext
        .dw     adpcm_a_off_ext
        .dw     adpcm_b_instrument
        .dw     adpcm_b_note_on
        .dw     adpcm_b_note_off
        .dw     fm_ctx_1
        .dw     fm_ctx_2
        .dw     fm_ctx_3
        .dw     fm_ctx_4
        .dw     fm_instrument
        .dw     fm_note_on
        .dw     fm_note_off
        .dw     adpcm_a_ctx_1
        .dw     adpcm_a_ctx_2
        .dw     adpcm_a_ctx_3
        .dw     adpcm_a_ctx_4
        .dw     adpcm_a_ctx_5
        .dw     adpcm_a_ctx_6
        .dw     adpcm_a_instrument
        .dw     adpcm_a_on
        .dw     adpcm_a_off
        .dw     op1_lvl
        .dw     op2_lvl
        .dw     op3_lvl
        .dw     op4_lvl
        .dw     fm_pitch
        .dw     ssg_ctx_1
        .dw     ssg_ctx_2
        .dw     ssg_ctx_3
        .dw     ssg_macro
        .dw     ssg_note_on
        .dw     ssg_note_off
        .dw     ssg_vol
        .dw     fm_vol
        .dw     ssg_env_period
        .dw     ssg_vibrato
        .dw     ssg_slide_up
        .dw     ssg_slide_down
        .dw     fm_vibrato
        .dw     fm_slide_up
        .dw     fm_slide_down


;;; Process a single NSS opcode
;;; ------
;;; bc: address in the stream pointing to the opcode and its args
;;; [a, bc, ix modified - other registers saved]
process_nss_opcode::
        ;; op
        ld      a, (hl)
        inc     hl
        ;; get function for opcode and tail call into it
        ld      ix, #nss_opcodes
        sla     a
        ld      b, #0
        ld      c, a
        add     ix, bc
        ld      b, 1(ix)
        ld      c, (ix)
        push    bc
        ret


;;;
;;; NSS opcodes
;;;

;;; WRITE_PORT_A
;;; generic write to YM2610 register reacheable from port A
;;; ------
;;; [ hl ]: register
;;; [hl+1]: value
write_port_a::
        ld      b, (hl)
        inc     hl
        ld      c, (hl)
        inc     hl
        call    ym2610_write_port_a
        ld      a, #1
        ret


;;; WRITE_PORT_B
;;; generic write to YM2610 register reacheable from port B
;;; ------
;;; [ hl ]: register
;;; [hl+1]: value
write_port_b::
        ld      b, (hl)
        inc     hl
        ld      c, (hl)
        inc     hl
        call    ym2610_write_port_b
        ld      a, #1
        ret


;;; NSS_JMP
;;; jump to a location from the start of the NSS stream
;;; ------
;;; [ hl ]: offset LSB
;;; [hl+1]: offset MSB
nss_jmp::
        push    bc
        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        inc     hl
        ld      ix, (state_current_ch_stream)
        ld      l, 2(ix)
        ld      h, 3(ix)
        add     hl, bc
        ld      4(ix), l
        ld      5(ix), h
        pop     bc
        ld      a, #1
        ret


;;; NSS_END
;;; signal the end of the NSS stream to the player
;;; ------
nss_end::
        call    snd_stream_stop
        ld      a, #0
        ret


;;; RUN_TIMER_B
;;; configure YM2610's timer B and start it
;;; ------
;;; [hl]: Timer B counter
run_timer_b::
        ;; reset all timers
        ld      b, #REG_TIMER_FLAGS
        ld      c, #0x30
        call    ym2610_write_port_a
        ;; configure timer B
        ld      b, #REG_TIMER_B_COUNTER
        ld      c, (hl)
        inc     hl
        call    ym2610_write_port_a
        ;; deconfigure timer A (TODO remove it)
        ld      b, #REG_TIMER_A_COUNTER_LSB
        ld      c, #0x0
        call    ym2610_write_port_a
        ld      b, #REG_TIMER_A_COUNTER_MSB
        ld      c, #0x0
        call    ym2610_write_port_a
        ;; start timer right away
        ld      a, #0
        ld      (state_timer_int_b_count), a
        ld      b, #REG_TIMER_FLAGS
        ld      c, #0x3A
        call    ym2610_write_port_a
        ei
        ld      a, #1
        ret


;;; WAIT_INT_B
;;; Suspend stream playback, resume after a number of Timer B
;;; interrupts has passed.
;;; ------
;;; [hl]: number of interrupts until playback resumes
wait_int_b::
        push    bc
        ;;  how many interrupts to wait for before moving on
        ld      a, (hl)
        inc     hl
        ;; register the wait for this channel
        ld      bc, (state_current_ch_wait_ticks)
        ld      (bc), a
        ;; if there was already a configured wait (multi-stream),
        ;; update it if the current opcode requests a smaller wait
        ld      b, a
        ld      a, (state_pending_timer_wait)
        cp      #0
        jr      z, _set_wait
        cp      b
        jr      c, _post_wait_int_b
_set_wait:
        ld      a, b
        ld      (state_pending_timer_wait), a
_post_wait_int_b:
        ;; reset playback contexts
        call    fm_ctx_reset
        call    ssg_ctx_reset
        call    adpcm_a_ctx_reset

        pop     bc
        ld      a, #0
        ret


;;; NSS_CALL
;;; Continue playback to a new position in the stream
;;; Recall the current position so that a NSS_RET opcode
;;; continue execution from there.
;;; Note: no NSS_CALL can be executed again before a NSS_RET
;;; ------
;;; [ hl ]: LSB forward offset to jump to
;;; [hl+1]: MSB forward offset to jump to
nss_call::
        push    bc

        ld      ix, (state_current_ch_stream)
        ;; bc: offset
        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        inc     hl
        ;; save current stream pos
        ld      (ix), l
        ld      1(ix), h
        ;; hl: start of stream
        ld      l, 2(ix)
        ld      h, 3(ix)
        ;; hl: new pos (call offset)
        add     hl, bc
        ld      4(ix), l
        ld      5(ix), h

        pop     bc
        ld      a, #1
        ret


;;; NSS_RET
;;; Continue playback past the previous NSS_CALL statement
;;; ------
nss_ret::
        ld      ix, (state_current_ch_stream)
        ;; hl: saved current stream pos
        ld      l, (ix)
        ld      h, 1(ix)
        ;; hl: restore new stream pos
        ld      4(ix), l
        ld      5(ix), h

        ld      a, #1
        ret


;;; NSS_NOP
;;; Empty operation
;;; ------
nss_nop::
        ld      a, #1
        ret
