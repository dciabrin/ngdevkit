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
        .include "timer.inc"

        .equ    CH_STREAM_SAVED, (state_ch_stream_saved_pos-state_ch_stream)
        .equ    CH_STREAM_START, (state_ch_stream_start-state_ch_stream)
        .equ    CH_STREAM_POS, (state_ch_stream_pos-state_ch_stream)
        .equ    CH_STREAM_ENTRIES, (state_ch_stream_entries-state_ch_stream)
        .equ    CH_STREAM_SIZE, (state_ch_stream_end-state_ch_stream)
        .equ    NB_YM2610_CHANNELS, 14

        .macro  .nss_op,op
_op_offset_'op: .dw op
        .equ    op_id_'op, ((_op_offset_'op - nss_opcodes) >> 1)
        .endm

        .macro  .nss_op_unused
        .dw     nss_nop
        .endm

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

;;; YM2610 channels used by this stream (1 bit per channel)
;;; ---
;;; This is used by the volume state tracker to distinguish between
;;; channels used by the music and those used for SFX
state_ch_bits::                 .blkw   1

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

;;; per-channel wait opcode cache
;;; ---
;;; Wait value used by the last wait opcode.
;;; When multiple streams are used, each YM2610 channel used in
;;; the NSS data gets a dedicated wait state
state_ch_wait_op_val::         .blkb   NB_YM2610_CHANNELS

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
state_ch_stream_entries::       .blkb   1
state_ch_stream_end:
        .blkb   CH_STREAM_SIZE*(NB_YM2610_CHANNELS-1)

;;; addresses/indices that points to state of the currently processed stream
state_current_ch_ctx::          .blkb   2
state_current_ch_wait_rows::    .blkb   2
state_current_ch_wait_op_val::  .blkb   2
state_current_ch_stream::       .blkb   2
state_stream_idx::              .blkb   1

;;; generic function pointer for current NSS processing function
state_nss_process::
        .blkb   1         ; jp
state_nss_process_func::
        .blkb   2         ; func offset in ROM


        ;; FIXME: temporary padding to ensures the next data sticks into
        ;; a single 256 byte boundary to make 16bit arithmetic faster
        .blkb   70


        .area  CODE


init_stream_state_tracker::
        ld      a, #0
        ld      (state_stream_in_use), a
        ld      bc, #0
        ld      (state_stream_instruments), bc
        ld      a, #0xc3        ; jp
        ld      (state_nss_process), a
        ;; init nss subsystems that may get called prior to playing music
        call    init_nss_fm_state_tracker
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
        ld      bc, #state_ch_wait_op_val
        ld      (state_current_ch_wait_op_val), bc
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
        ld      iy, (state_current_ch_stream)
        ld      l, CH_STREAM_POS(iy)
        ld      h, CH_STREAM_POS+1(iy)
_loop_opcode:
        call    state_nss_process
        or      a
        jp      nz, _loop_opcode
        ;; no more opcodes can be processed, save stream's new pos
        ld      iy, (state_current_ch_stream)
        ld      CH_STREAM_POS(iy), l
        ld      CH_STREAM_POS+1(iy), h
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
        ld      hl, (state_current_ch_wait_op_val)
        inc     hl
        ld      (state_current_ch_wait_op_val), hl
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
        ;; check whether one row has passed and further processing is needed
        ld      a, (state_timer_tick_reached)
        bit     TIMER_CONSUMER_STREAM_BIT, a
        jp      z, _end_update_stream
        ;; check whether any stream is ready for processing more NSS opcodes
        ld      a, (state_timer_ticks_per_row)
        ld      b, a
        ld      a, (state_timer_ticks_count)
        cp      b
        jp      c, _post_process_nss_opcodes
        ;; process the NSS opcodes (this will update the pipeline)
        ;; the next row processing will take place once a new row is reached.
        call    update_streams_wait_rows
        call    process_streams_opcodes
        ld      a, #0
        ld      (state_timer_ticks_count), a
        call    timer_update_ticks_for_next_row
_post_process_nss_opcodes:
        ;; process the current stream pipeline
        ;; the next processing will take place once a new tick is reached
        call    run_fm_pipeline
        call    run_ssg_pipeline
        call    run_adpcm_a_pipeline
        call    run_adpcm_b_pipeline
        ld      a, (state_timer_tick_reached)
        res     TIMER_CONSUMER_STREAM_BIT, a
        ld      (state_timer_tick_reached), a
_end_update_stream:
        pop     bc
        pop     hl
        ret


;;; Initialize subsystems' state trackers and stream wait state
;;; ------
snd_stream_reset_state::
stream_reset_state::
        ;; reset state trackers
        call    init_nss_fm_state_tracker
        call    init_nss_ssg_state_tracker
        call    init_nss_adpcm_state_tracker
        call    init_nss_adpcm_b_state_tracker
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
stream_play::
        ;; (de) = 0xff: inline NSS stream
        ;; (de) > 0: multi-stream NSS
        ld      a, (de)
        cp      #0xff
        jp      nz, stream_play_multi

        ;; prepare stream playback for a single stream
        call    stream_stop

        ;; setup current instruments
        ld      (state_stream_instruments), bc

        ;; setup playback for a single NSS steam
        ld      a, #1
        ld      (state_streams), a

        ;; setup enabled channels bitfield for this music
        inc     de
        ld      a, (de)
        ld      c, a
        inc     de
        ld      a, (de)
        ld      b, a
        ld      (state_ch_bits), bc

        ;; for single NSS stream, ctx switch table is not used (nop),
        ;; context opcodes are part of the stream itself
        ld      hl, #state_ch_ctx_switch
        ld      a, #op_id_nss_nop
        ld      (hl), a

        ;; init stream state
        inc     de
        ld      (state_ch_stream_start), de
        ld      (state_ch_stream_pos), de

        ;; reset state trackers
        call    stream_reset_state

        ;; start stream playback, it will get preempted
        ;; as soon as a wait opcode shows up in the stream
        call    update_stream_state_tracker
        ret


;;; Initialize the context table based on the number and type
;;; of channels in use in the stream
;;; ------
;;; bc: stream usage bitfield
;;; [a, bc, de, hl modified]
snd_configure_stream_ctx_switches::
        ld      hl, #stream_all_ctx_switch
        ld      de, #state_ch_ctx_switch
        ld      a, #15
_stream_ctx_set:
        bit     0, c
        jr      z, _stream_ctx_cfg_next
        ldi
        dec     l
_stream_ctx_cfg_next:
        inc     l
        srl     b
        rr      c
        dec     a
        jr      nz, _stream_ctx_set
        ret
;;; Context switch action when switching to a new per-channel stream
stream_all_ctx_switch::
        .db     op_id_fm_ctx_1, op_id_fm_ctx_2, op_id_fm_ctx_3, op_id_fm_ctx_4
        .db     op_id_ssg_ctx_1, op_id_ssg_ctx_2, op_id_ssg_ctx_3, op_id_nss_nop
        .db     op_id_adpcm_a_ctx_1, op_id_adpcm_a_ctx_2, op_id_adpcm_a_ctx_3
        .db     op_id_adpcm_a_ctx_4, op_id_adpcm_a_ctx_5, op_id_adpcm_a_ctx_6
        .db     op_id_adpcm_b_ctx


;;; Play music or sfx from a pre-compiled list of NSS opcodes,
;;; encoded as multiple NSS streams (compact representation)
;;; ------
;;; bc: nullsound instruments
;;; de: NSS data (compact representation)
;;; [a modified - other registers saved]
stream_play_multi::
        call    stream_stop
        push    de
        pop     iy

        ;; setup current instruments
        ld      (state_stream_instruments), bc

        ;; a: number of streams
        ld      a, (iy)
        ld      (state_streams), a

        ;; setup enabled channels bitfield for this music and
        ;; configure every stream with the right channel ctx opcode
        inc     iy
        ld      c, (iy)
        ld      b, 1(iy)
        ld      (state_ch_bits), bc
        call    snd_configure_stream_ctx_switches

        ;; setup speed and groove
        inc     iy
        inc     iy
        call    timer_init_ticks

        ;; hl: stream data from NSS
        push    iy
        pop     hl

        ;; setup the generic NSS processing function
        ld      bc, #process_nss_opcode
        ld      (state_nss_process_func), bc

        ;; init streams state
        ld      iy, #state_ch_stream
        ld      de, #CH_STREAM_SIZE
        ld      a, (state_streams)
        ld      c, a
_stream_play_init_loop:
        ;; a: stream data LSB
        ld      a, (hl)
        ld      CH_STREAM_START(iy), a
        ld      CH_STREAM_POS(iy), a
        inc     hl
        ;; a: stream data MSB
        ld      a, (hl)
        ld      CH_STREAM_START+1(iy), a
        ld      CH_STREAM_POS+1(iy), a
        inc     hl
        add     iy, de
        dec     c
        jr      nz, _stream_play_init_loop

        ;; reset state trackers
        call    volume_reset_music_levels
        call    stream_reset_state

        ;; start stream playback, it will get preempted
        ;; as soon as a wait opcode shows up in the stream
        call    update_stream_state_tracker
        ret


;;; Stop music or sfx stream playback
;;; ------
;;; [a modified - other registers saved]
snd_stream_stop::
stream_stop::
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
;;; hl [IN]: arguments of the current NSS opcode in the stream
;;;          when the function for a NSS opcode is called, hl points
;;;          to the arguments of that opcode.
;;;          on function exit, hl must point to the next NSS opcode
;;;          in the stream
;;; a [OUT]: 1: processing of the next opcode can continue
;;;          0: processing must stop (the playback must wait for
;;;             the timer for sync, or the stream is finished)
;;;
;;; [a and hl modified - other registers must be saved]
nss_opcodes:
        ;; 0x00
        .nss_op write_port_a
        .nss_op write_port_b
        .nss_op nss_jmp
        .nss_op nss_end
        .nss_op timer_tempo
        .nss_op wait_n_rows
        .nss_op nss_call
        .nss_op nss_ret
        ;; 0x08
        .nss_op nss_nop
        .nss_op row_speed
        .nss_op row_groove
        .nss_op wait_last_rows
        .nss_op adpcm_b_instrument
        .nss_op adpcm_b_note_on
        .nss_op adpcm_b_note_off
        .nss_op fm_ctx_1
        ;; 0x10
        .nss_op fm_ctx_2
        .nss_op fm_ctx_3
        .nss_op fm_ctx_4
        .nss_op fm_instrument
        .nss_op fm_note_on
        .nss_op fm_note_off
        .nss_op adpcm_a_ctx_1
        .nss_op adpcm_a_ctx_2
        ;; 0x18
        .nss_op adpcm_a_ctx_3
        .nss_op adpcm_a_ctx_4
        .nss_op adpcm_a_ctx_5
        .nss_op adpcm_a_ctx_6
        .nss_op adpcm_a_instrument
        .nss_op adpcm_a_on
        .nss_op adpcm_a_off
        .nss_op op1_lvl
        ;; 0x20
        .nss_op op2_lvl
        .nss_op op3_lvl
        .nss_op op4_lvl
        .nss_op fm_pitch
        .nss_op ssg_ctx_1
        .nss_op ssg_ctx_2
        .nss_op ssg_ctx_3
        .nss_op ssg_macro
        ;; 0x28
        .nss_op ssg_note_on
        .nss_op ssg_note_off
        .nss_op ssg_vol
        .nss_op fm_vol
        .nss_op ssg_env_period
        .nss_op_unused
        .nss_op_unused
        .nss_op_unused
        ;; 0x30
        .nss_op_unused
        .nss_op_unused
        .nss_op_unused
        .nss_op adpcm_b_vol
        .nss_op adpcm_a_vol
        .nss_op fm_pan
        .nss_op_unused
        .nss_op_unused
        ;; 0x38
        .nss_op_unused
        .nss_op ssg_delay
        .nss_op fm_delay
        .nss_op adpcm_a_delay
        .nss_op adpcm_b_ctx
        .nss_op_unused
        .nss_op_unused
        .nss_op ssg_pitch
        ;; 0x40
        .nss_op_unused
        .nss_op_unused
        .nss_op_unused
        .nss_op_unused
        .nss_op_unused
        .nss_op fm_cut
        .nss_op ssg_cut
        .nss_op adpcm_a_cut
        ;; 0x48
        .nss_op adpcm_b_cut
        .nss_op adpcm_b_delay
        .nss_op adpcm_a_retrigger
        .nss_op adpcm_a_pan
        .nss_op adpcm_b_pan
        .nss_op_unused
        .nss_op nss_call_table
        .nss_op fm_note_on_and_wait
        ;; 0x50
        .nss_op ssg_note_on_and_wait
        .nss_op adpcm_a_on_and_wait
        .nss_op_unused
        .nss_op arpeggio
        .nss_op arpeggio_speed
        .nss_op arpeggio_off
        .nss_op quick_legato_up
        .nss_op quick_legato_down
        ;; 0x58
        .nss_op vol_slide_off
        .nss_op vol_slide_up
        .nss_op vol_slide_down
        .nss_op note_slide_off
        .nss_op note_slide_up
        .nss_op note_slide_down
        .nss_op note_pitch_slide_up
        .nss_op note_pitch_slide_down
        ;; 0x60
        .nss_op note_portamento
        .nss_op vibrato
        .nss_op vibrato_off
        .nss_op legato
        .nss_op legato_off



;;; Process a single NSS opcode
;;; ------
;;; bc: address in the stream pointing to the opcode and its args
;;; [a, bc, iy modified - other registers saved]
process_nss_opcode::
        ;; op
        ld      a, (hl)
        inc     hl
        ;; get function for opcode and tail call into it
        ld      iy, #nss_opcodes
        sla     a
        ld      b, #0
        ld      c, a
        add     iy, bc
        ld      b, 1(iy)
        ld      c, (iy)
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
        ld      iy, (state_current_ch_stream)
        ;; hl: start of stream
        ld      l, CH_STREAM_START(iy)
        ld      h, CH_STREAM_START+1(iy)
        ;; hl: new pos (call offset)
        add     hl, bc
        ld      CH_STREAM_POS(iy), l
        ld      CH_STREAM_POS+1(iy), h
        pop     bc
        ld      a, #1
        ret


;;; NSS_END
;;; signal the end of the NSS stream to the player
;;; ------
nss_end::
        ;; signal the end of playback for the entire music
        call    stream_stop
        ;; ensure that the current channel's pipeline is stopped
        ;; TODO use FX and PIPELINE macros rather than hardcodes
        xor     a
        ld      (ix), a
        ld      1(ix), a

        ld      a, #0
        ret


;;; WAIT_N_ROWS
;;; Suspend stream playback, resume after a number of rows
;;; worth of time has passed (Timer B interrupts * speed).
;;; ------
;;; [hl]: number of interrupts until playback resumes
wait_n_rows::
        push    bc
        ;;  how many interrupts to wait for before moving on
        ld      a, (hl)
        inc     hl
        ;; recall this wait value for this channel
        ld      bc, (state_current_ch_wait_op_val)
        ld      (bc), a
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


;;; WAIT_LAST_ROWS
;;; Suspend stream playback, resume after a number of rows
;;; worth of time has passed (same as the last wait_n_rows)
;;; ------
wait_last_rows::
        push    bc
        ;; last wait for this channel
        ld      bc, (state_current_ch_wait_op_val)
        ld      a, (bc)
        ;; register the wait for this channel
        ld      bc, (state_current_ch_wait_rows)
        ld      (bc), a

        jp      _post_wait_rows


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

        ld      iy, (state_current_ch_stream)
        ;; bc: offset
        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        inc     hl
        ;; save current stream pos
        ld      CH_STREAM_SAVED(iy), l
        ld      CH_STREAM_SAVED+1(iy), h
        ;; hl: start of stream
        ld      l, CH_STREAM_START(iy)
        ld      h, CH_STREAM_START+1(iy)
        ;; hl: new pos (call offset)
        add     hl, bc
        ld      CH_STREAM_POS(iy), l
        ld      CH_STREAM_POS+1(iy), h

        pop     bc
        ld      a, #1
        ret


;;; NSS_CALL_TABLE
;;; Set up a series of calls to different locations in the stream
;;; ------
;;; [ hl ]: number of calls
nss_call_table::
        ;; bc: number of calls
        ld      a, (hl)
        inc     hl

        ;; recall the number of entries in the call table
        ld      iy, (state_current_ch_stream)
        ld      CH_STREAM_ENTRIES(iy), a

        push    bc
        ld      bc, #process_table_entry
        ld      (state_nss_process_func), bc
        pop     bc

        ld      a, #1
        ret


;;; Continue playback to a new position in the stream
;;; Recall the current position so that a NSS_RET opcode
;;; continues execution from there.
;;; Note: no CALL entry can be processed again before a NSS_RET
;;; ------
;;; [ hl ]: pattern offset in the entry table
process_table_entry::
        push    bc

        ;; a: entry
        ld      a, (hl)
        inc     hl

        ld      iy, (state_current_ch_stream)

        ;; save current stream pos
        ld      CH_STREAM_SAVED(iy), l
        ld      CH_STREAM_SAVED+1(iy), h

        ;; hl: start of stream
        ld      l, CH_STREAM_START(iy)
        ld      h, CH_STREAM_START+1(iy)

        ;; hl: offset in entry table
        ld      b, #0xff
        ld      c, a
        add     hl, bc
        add     hl, bc

        ;; bc: pattern offset
        ld      c, (hl)
        inc     hl
        ld      b, (hl)

        ;; hl: start of stream
        ld      l, CH_STREAM_START(iy)
        ld      h, CH_STREAM_START+1(iy)

        ;; hl: new pos (call offset)
        add     hl, bc
        ld      CH_STREAM_POS(iy), l
        ld      CH_STREAM_POS+1(iy), h

        ;; record that one call entry has been processed
        dec     CH_STREAM_ENTRIES(iy)

        ld      bc, #process_nss_opcode
        ld      (state_nss_process_func), bc

        pop     bc
        ld      a, #1
        ret


;;; NSS_RET
;;; Continue playback past the previous NSS_CALL statement
;;; ------
nss_ret::
        ld      iy, (state_current_ch_stream)
        ;; hl: saved current stream pos
        ld      l, CH_STREAM_SAVED(iy)
        ld      h, CH_STREAM_SAVED+1(iy)
        ;; hl: restore new stream pos
        ld      CH_STREAM_POS(iy), l
        ld      CH_STREAM_POS+1(iy), h

        push    bc
        ld      bc, #process_nss_opcode
        xor     a
        cp      CH_STREAM_ENTRIES(iy)
        jr      z, _ret_set_process
        ld      bc, #process_table_entry
_ret_set_process:
        ld      (state_nss_process_func), bc
        pop     bc

        ld      a, #1
        ret


;;; NSS_NOP
;;; Empty operation
;;; ------
nss_nop::
        ld      a, #1
        ret
