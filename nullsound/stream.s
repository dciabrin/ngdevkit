;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2023-2024 Damien Ciabrini
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

        .equ    CH_STREAM_SAVED, (state_ch_stream_saved_pos-state_ch_stream)
        .equ    CH_STREAM_START, (state_ch_stream_start-state_ch_stream)
        .equ    CH_STREAM_POS, (state_ch_stream_pos-state_ch_stream)
        .equ    CH_STREAM_SIZE, (state_ch_stream_end-state_ch_stream)
        .equ    NB_YM2610_CHANNELS, 14
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

;;; number of streams to play
state_streams::                 .blkb   1
        
;;; per-channel context switch function
;;; ---
;;; When multiple streams are used, each stream represents a unique
;;; YM2610 channel. Before evaluating NSS opcode for a stream, the
;;; player has to set up the right NSS context, by calling the
;;; right <x>_CTX opcode.
state_ch_ctx_switch::           .blkb   NB_YM2610_CHANNELS

;;; per-channel wait state
;;; ---
;;; Wait for a "number of rows" worth of time until processing further
;;; opcodes in the stream.
;;; When multiple streams are used, each YM2610 channel used in
;;; the NSS data gets a dedicated wait state
state_ch_wait_rows::           .blkb   NB_YM2610_CHANNELS

;;; per-channel playback state
;;; ---
;;; Keep track of positional information for streams.
;;;  - (absolute) saved caller position in the stream, for ret opcodes
;;;  - (absolute) current position in the stream
;;;  - (absolute) stream start for computing offset of jmp/call opcodes
;;; When multiple streams are used, each YM2610 channel used in
;;; the NSS data gets a dedicated playback state
state_ch_stream:
state_ch_stream_saved_pos::     .blkb   2
state_ch_stream_start::         .blkb   2
state_ch_stream_pos::           .blkb   2
state_ch_stream_end:
        .blkb   CH_STREAM_SIZE*(NB_YM2610_CHANNELS-1)

;;; addresses/indices that points to state of the currently processed stream
state_current_ch_ctx::          .blkb   2
state_current_ch_wait_rows::    .blkb   2
state_current_ch_stream::       .blkb   2
state_stream_idx::              .blkb   1

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

;;; substract one row from every stream's wait state
;;; ------
;;; . When called, one row passed since last update, so substract
;;;   it from the wait state of all streams.
;;; . Streams whose wait_rows value goes down to 0 become ready
;;;   for processing NSS opcodes (in process_streams_opcodes)
;;; . By design, substraction should never yield a negative wait
;;; [no register modified]
update_streams_wait_rows::
        push    de
        push    bc
        push    hl
        ;; c: streams playing
        ld      a, (state_streams)
        ld      c, a
        ;; hl: streams wait state
        ld      hl, #state_ch_wait_rows
_tick_sub_loop:
        dec     (hl)
        inc     hl
        dec     c
        jr      nz, _tick_sub_loop

        pop     hl
        pop     bc
        pop     de
        ret


;;; process opcodes for all the streams that are not waiting for ticks
;;; ------
;;; [all registers modified]
process_streams_opcodes::
        ;; init stream state pointers
        ld      a, #0
        ld      (state_stream_idx), a
        ld      bc, #state_ch_wait_rows
        ld      (state_current_ch_wait_rows), bc
        ld      bc, #state_ch_ctx_switch
        ld      (state_current_ch_ctx), bc
        ld      bc, #state_ch_stream
        ld      (state_current_ch_stream), bc
_loop_chs:
        ;; [de]: wait ticks for current stream
        ld      de, (state_current_ch_wait_rows)
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

        ;; hl: current stream's position
        ld      ix, (state_current_ch_stream)
        ld      l, CH_STREAM_POS(ix)
        ld      h, CH_STREAM_POS+1(ix)
_loop_opcode:
        call    process_nss_opcode
        or      a
        jp      nz, _loop_opcode
        ;; no more opcodes can be processed, save stream's new pos
        ld      ix, (state_current_ch_stream)
        ld      CH_STREAM_POS(ix), l
        ld      CH_STREAM_POS+1(ix), h
_post_ch_process:
        ld      a, (state_streams)
        ld      b, a
        ld      a, (state_stream_idx)
        inc     a
        cp      b
        jr      nc, _end_process
        ld      (state_stream_idx), a
        ld      hl, (state_current_ch_wait_rows)
        inc     hl
        ld      (state_current_ch_wait_rows), hl
        ld      hl, (state_current_ch_ctx)
        inc     hl
        ld      (state_current_ch_ctx), hl
        ld      hl, (state_current_ch_stream)
        ld      bc, #CH_STREAM_SIZE
        add     hl, bc
        ld      (state_current_ch_stream), hl
        jr      _loop_chs
_end_process:
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
        jp      z, _end_update_stream
        ;; check whether one row has passed and any stream is ready for
        ;; processing more NSS opcodes
        ld      a, (state_timer_ticks_per_row)
        ld      b, a
        ld      a, (state_timer_ticks_count)
        cp      b
        ;; if we can't, check whether we have macros or effects to process
        jp      c, _check_update_macros_and_effects
        call    update_streams_wait_rows
        call    process_streams_opcodes
        ;; reset row and tick reached counters and exit
        ld      a, #0
        ld      (state_timer_ticks_count), a
        jp      _reset_tick_reached
_check_update_macros_and_effects:
        ld      a, (state_timer_tick_reached)
        cp      a, #0
        jp      z, _end_update_stream
        call    update_fm_effects
        call    update_ssg_macros_and_effects
_reset_tick_reached:
        ;; reset the tick reached marker, next macro/effect processing
        ;; will take place once a new tick is reached
        ld      a, #0
        ld      (state_timer_tick_reached), a
_end_update_stream:
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

        ;; init stream wait trackers
        ld      a, #1
        ld      hl, #state_ch_wait_rows
        ld      (hl), a
        ld      a, (state_streams)
        dec     a
        cp      #0
        jr      z, _post_memset_wait_rows
        ld      b, #0
        ld      c, a
        ld      d, h
        ld      e, l
        inc     de
        ldir
_post_memset_wait_rows:
        ret


;;; Play music or sfx from a series of NSS sound opcodes stored
;;; in ROM in inline (1 stream) or compact (multi-stream) format
;;; ------
;;; bc: nullsound instruments
;;; de: nullsound stream (inline or compact format)
;;; [a modified - other registers saved]
snd_stream_play::
        ;; (de) = 0xff: inline NSS stream
        ;; (de) > 0: multi-stream NSS
        ld      a, (de)
        cp      #0xff
        jp      nz, snd_multi_stream_play

        ;; prepare stream playback for a single stream
        call    snd_stream_stop

        ;; setup current instruments
        ld      (state_stream_instruments), bc

        ;; setup playback for a single NSS steam
        ld      a, #1
        ld      (state_streams), a

        ;; for single NSS stream, ctx switch table is not used (nop),
        ;; context opcodes are part of the stream itself
        ld      hl, #state_ch_ctx_switch
        ld      a, #OPCODE_NSS_NOP
        ld      (hl), a

        ;; init stream state
        inc     de
        ld      (state_ch_stream_start), de
        ld      (state_ch_stream_pos), de

        ;; reset state trackers
        call    snd_stream_reset_state

        ;; start stream playback, it will get preempted
        ;; as soon as a wait opcode shows up in the stream
        call    update_stream_state_tracker
        ret


;;; Play music or sfx from a pre-compiled list of NSS opcodes,
;;; encoded as multiple NSS streams (compact representation)
;;; ------
;;; bc: nullsound instruments
;;; de: NSS data (compact representation)
;;; [a modified - other registers saved]
snd_multi_stream_play::
        call    snd_stream_stop
        push    de
        pop     ix

        ;; setup current instruments
        ld      (state_stream_instruments), bc

        ;; a: number of streams
        ld      a, (ix)
        ld      (state_streams), a

        ;; configure every stream with the right channel ctx opcode
        ;; hl: stream data from NSS
        inc     ix
        push    ix
        pop     hl
        ;; de: stream contexts
        ld      de, #state_ch_ctx_switch
        ;; bc: number of streams
        ld      b, #0
        ld      c, a
        ldir

        ;; init streams state
        ld      ix, #state_ch_stream
        ld      de, #CH_STREAM_SIZE
        ld      a, (state_streams)
        ld      c, a
_stream_play_init_loop:
        ;; a: stream data LSB
        ld      a, (hl)
        ld      CH_STREAM_START(ix), a
        ld      CH_STREAM_POS(ix), a
        inc     hl
        ;; a: stream data MSB
        ld      a, (hl)
        ld      CH_STREAM_START+1(ix), a
        ld      CH_STREAM_POS+1(ix), a
        inc     hl
        add     ix, de
        dec     c
        jr      nz, _stream_play_init_loop

        ;; reset state trackers
        call    snd_stream_reset_state

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
        ld      (state_timer_ticks_count), a
        ld      (state_timer_ticks_per_row), a
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
        .dw     timer_tempo
        .dw     wait_rows
        .dw     nss_call
        .dw     nss_ret
        .dw     nss_nop
        .dw     row_speed
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
        .dw     adpcm_b_vol
        .dw     adpcm_a_vol


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
        ;; bc: location offset
        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        ld      ix, (state_current_ch_stream)
        ;; hl: start of stream
        ld      l, CH_STREAM_START(ix)
        ld      h, CH_STREAM_START+1(ix)
        ;; hl: new pos (call offset)
        add     hl, bc
        ld      CH_STREAM_POS(ix), l
        ld      CH_STREAM_POS+1(ix), h
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


;;; WAIT_ROWS
;;; Suspend stream playback, resume after a number of rows
;;; worth of time has passed (Timer B interrupts * speed).
;;; ------
;;; [hl]: number of interrupts until playback resumes
wait_rows::
        push    bc
        ;;  how many interrupts to wait for before moving on
        ld      a, (hl)
        inc     hl
        ;; register the wait for this channel
        ld      bc, (state_current_ch_wait_rows)
        ld      (bc), a
_post_wait_rows:
        ;; reset playback contexts (only useful for inline stream)
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
        ld      CH_STREAM_SAVED(ix), l
        ld      CH_STREAM_SAVED+1(ix), h
        ;; hl: start of stream
        ld      l, CH_STREAM_START(ix)
        ld      h, CH_STREAM_START+1(ix)
        ;; hl: new pos (call offset)
        add     hl, bc
        ld      CH_STREAM_POS(ix), l
        ld      CH_STREAM_POS+1(ix), h

        pop     bc
        ld      a, #1
        ret


;;; NSS_RET
;;; Continue playback past the previous NSS_CALL statement
;;; ------
nss_ret::
        ld      ix, (state_current_ch_stream)
        ;; hl: saved current stream pos
        ld      l, CH_STREAM_SAVED(ix)
        ld      h, CH_STREAM_SAVED+1(ix)
        ;; hl: restore new stream pos
        ld      CH_STREAM_POS(ix), l
        ld      CH_STREAM_POS+1(ix), h

        ld      a, #1
        ret


;;; NSS_NOP
;;; Empty operation
;;; ------
nss_nop::
        ld      a, #1
        ret
