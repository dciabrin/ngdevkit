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
        ld      TRIGGER_DELAY(ix), a
        xor     a
        set     BIT_TRIGGER_ACTION_DELAY, a
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
        ;; is the trigger a delay?
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _trigger_post_delay
        ;; check whether delay is reached
        dec     TRIGGER_DELAY(ix)
        jr      nz, _trigger_end
        jr      _trigger_load_and_clear
_trigger_post_delay:
_trigger_end:
        ret

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

        ;; trigger is finished
        xor     a
        ld      TRIGGER_ACTION(ix), a
        res     BIT_FX_TRIGGER, FX(ix)

        ret
