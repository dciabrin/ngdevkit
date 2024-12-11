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

;;; Trigger effect (delay, cut...), common functions for FM and SSG
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"


        .area  CODE


;;; Enable delayed trigger for the next note and volume
;;; (note and volume and played after a number of ticks)
;;; ------
;;;   ix  : state for channel
;;; [ hl ]: delay
;;; [ hl modified ]
trigger_delay_init::
        ;; a: delay
        ld      a, (hl)
        inc     a
        inc     hl

        ;; configure trigger FX for delay
        ld      TRIGGER_CUR(ix), a
        xor     a
        set     BIT_TRIGGER_ACTION_DELAY, a
        ld      TRIGGER_ACTION(ix), a
        set     BIT_FX_TRIGGER, FX(ix)

        ret


;;; Enable delayed cut for the note currently playing
;;; (note is stopped after a defined number of steps)
;;; ------
;;;   ix  : state for channel
;;; [ hl ]: delay
;;; [ hl modified ]
trigger_cut_init::
        ;; a: delay
        ld      a, (hl)
        inc     a
        inc     hl

        ;; configure trigger FX for cut
        ld      TRIGGER_CUR(ix), a
        xor     a
        set     BIT_TRIGGER_ACTION_CUT, a
        ld      TRIGGER_ACTION(ix), a
        set     BIT_FX_TRIGGER, FX(ix)

        ret


;;; Enable another note trigger after a defined number of steps
;;; ------
;;;   ix  : state for channel
;;; [ hl ]: delay
;;; [ hl modified ]
trigger_retrigger_init::
        ;; a: delay
        ld      a, (hl)
        inc     hl

        ;; configure trigger FX for retrigger
        ld      TRIGGER_ARG(ix), a
        ld      TRIGGER_CUR(ix), a
        xor     a
        set     BIT_TRIGGER_ACTION_RETRIGGER, a
        ld      TRIGGER_ACTION(ix), a
        set     BIT_FX_TRIGGER, FX(ix)

        ret


;;; Call an function from the action lookup table
;;; ------
;;; hl: function lookup table
;;; bc: offset in bytes in the function lookup table
;;;  a: input (note, vol...)
;;; [bc, de modified]
trigger_action_function::
        push    hl

        ;; bc: function to call
        add     hl, bc
        ld      c, (hl)
        inc     hl
        ld      b, (hl)

        ;; call
        ld      de, #_trigger_post_action
        push    de
        push    bc
        ret
_trigger_post_action:
        pop     hl
        ret


;;; Update the trigger configuration for the current channel
;;; ------
;;; ix: mirrored state of the current channel
;;; hl: function lookup table for the current channel
;;; [hl, bc, de modified]
eval_trigger_step::
        ;; if this is a retrigger, check whether we reached the last tick
        ;; for this row, and stop it after this eval
        bit     BIT_TRIGGER_ACTION_RETRIGGER, TRIGGER_ACTION(ix)
        jr      z, _trigger_post_retrigger_check
        ld      a, (state_timer_ticks_per_row)
        ld      b, a
        ld      a, (state_timer_ticks_count)
        inc     a
        sub     b
        jr      c, _trigger_post_retrigger_check
        res     BIT_FX_TRIGGER, FX(ix)
_trigger_post_retrigger_check:

        ;; check whether delay is reached for trigger action
        dec     TRIGGER_CUR(ix)
        jr      nz, _trigger_end
        ;; if so, run the configured action
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _trigger_not_a_delay
        jr      _trigger_load_and_clear
_trigger_not_a_delay:
        bit     BIT_TRIGGER_ACTION_CUT, TRIGGER_ACTION(ix)
        jr      z, _trigger_not_a_cut
        jr      _trigger_cut_note
_trigger_not_a_cut:
        ;; is the trigger a cut?
        bit     BIT_TRIGGER_ACTION_RETRIGGER, TRIGGER_ACTION(ix)
        jr      z, _trigger_not_a_retrigger
        jr      _trigger_retrigger_note
_trigger_not_a_retrigger:

_trigger_end:
        ret


;;; trigger: load delayed note/vol
_trigger_load_and_clear:
        ;; load new note?
        bit     BIT_TRIGGER_LOAD_NOTE, TRIGGER_ACTION(ix)
        jr      z, _trigger_post_load_note
        ld      a, TRIGGER_NOTE(ix)
        ld      bc, #TRIGGER_LOAD_NOTE_FUNC
        call    trigger_action_function
_trigger_post_load_note:
        ;; load new vol?
        bit     BIT_TRIGGER_LOAD_VOL, TRIGGER_ACTION(ix)
        jr      z, _trigger_post_load_vol
        ld      a, TRIGGER_VOL(ix)
        ld      bc, #TRIGGER_LOAD_VOL_FUNC
        call    trigger_action_function
_trigger_post_load_vol:
        res     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        res     BIT_FX_TRIGGER, FX(ix)
        ret


;;; trigger: cut current note
_trigger_cut_note:
        ld      bc, #TRIGGER_STOP_NOTE_FUNC
        call    trigger_action_function
        res     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        res     BIT_FX_TRIGGER, FX(ix)
        ret


;;; trigger: restart current note
_trigger_retrigger_note:
        ld      bc, #TRIGGER_LOAD_NOTE_FUNC
        call    trigger_action_function
        ;; rearm trigger for the next step
        ld      a, TRIGGER_ARG(ix)
        ld      TRIGGER_CUR(ix), a
        ret

