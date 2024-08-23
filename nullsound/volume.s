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

;;; The following driver is based on doc found on neogeodev wiki
;;; https://wiki.neogeodev.org/index.php?title=68k/Z80_communication

        .module nullsound

        .include "ym2610.inc"
        .include "ports.inc"
        .include "timer.inc"

        ;; TODO replace hardcoded offset with struct include
        .equ    PROPS_VOL_OFFSET, 21


;;;
;;; Volume state tracker
;;; -------------------
;;;  Keep track of the global volume and fade out state
;;;
        .area  DATA

;;; Current global level for music [0..15]
;;; -------------------
;;; This acts as a way of controlling how loud music playback is
;;; The global level serves as the basic to 4 independent levels
;;; (resp. FM, SSG, ADPCM-A and ADPCM-B) because all these channels
;;; have different level sensitivity (resp. 128, 16, 32, 256) as
;;; well as different volume decay profiles.
;;; The volume capabilities are modelled against the SSG properties,
;;; because that's the most limiting type of sound in the YM2610.
;;;   . There are only 16 levels because that's what SSG can output
;;;   . The volume decay for SSG follows an exponential curve:
;;;     volume gets half as loud every two steps. FM follows a faster
;;;     curve, ADPCM-A a slower one. ADPCM-B decays linearly.
;;;   . to accomodate those decays, we define a volume ramp for
;;;     each channel type, so every 16 levels can map to a consistent
;;;     volume drop across channels.
state_volume_music_level::      .blkb   1

;;; Master level for ADPCM-A
;;; NOTE: the lowest volume achievable per channel with ADPCM-A seems
;;; to be a bit too loud, so for the time being the fade out action
;;; relies on the master ADPCM-A volume to implement the effect.
;;; This has the unfortunate side effect that SFX are faded out at the
;;; same time.
state_volume_adpcm_a_master::   .blkb   1

;;; Music fade out in progress
state_volume_fade_out::         .blkb   1

;;; Current music volume during the fade out
;;; this is a fixed point value (4bit integer + 2bit fractional) that
;;; goes from the current music level down to 0, for a total of 64
;;; possible levels for channels with that capability.
;;; the level is updated at every music tick
state_volume_fade_progress::    .blkb   1

;;; Fade out speed. Fixed point value (4bit integer + 2bit fractional)
state_volume_fade_speed::       .blkb   1

        .area  CODE

;;; SSG: the linear decrease ramp [0..0xf] yields an exponential volume decay
state_volume_ssg_ramp::
        .db     0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00, 0x00
;;; FM: scaled linear decrease [0..0x7f] to approximate the exponential volume decay from SSG
state_volume_fm_ramp::
        .db     0x7f, 0x40, 0x37, 0x33, 0x2e, 0x2a, 0x26, 0x22, 0x1d, 0x19, 0x15, 0x11, 0x0c, 0x08, 0x04, 0x00, 0x00
;;; ADPCM-A: scaled linear decrease [0..0x1f] to approximate the exponential volume decay from SSG
;;; NOTE: MAME seems to have a problem with 0x1f? some channels play a faint volume, others cut it
state_volume_adpcm_a_ramp::
        .db     0x1f, 0x1e, 0x1e, 0x1d, 0x1d, 0x1c, 0x1c, 0x1b, 0x1a, 0x18, 0x15, 0x12, 0x0b, 0x07, 0x03, 0x00, 0x00
;;; ADPCM-B: scaled log decrease [0..0x40] to approximate the exponential volume decay from SSG
state_volume_adpcm_b_ramp::
        .db     0x40, 0x3f, 0x3f, 0x3e, 0x3e, 0x3d, 0x3d, 0x3c, 0x3b, 0x39, 0x35, 0x31, 0x2a, 0x21, 0x13, 0x0, 0x0

;;; ADPCM-A master: linear volume decay [0..0x3f]
state_volume_adpcm_a_master_ramp::
        .db     0x3f, 0x3b, 0x37, 0x33, 0x2e, 0x2a, 0x26, 0x22, 0x1d, 0x19, 0x15, 0x11, 0x0c, 0x08, 0x04, 0x00, 0x00



init_volume_state_tracker::
        ;; reset music volume to max (no attenuation)
        ld      a, #0x0f
        ld      (state_volume_music_level), a
        ;; reset channel levels
        ld      a, #0
        ld      (state_fm_volume_attenuation), a
        ld      (state_ssg_volume_attenuation), a
        ld      (state_adpcm_a_volume_attenuation), a
        ld      (state_adpcm_b_volume_attenuation), a
        ld      (state_volume_adpcm_a_master), a
        ;; reset fade out operation
        ld      a, #0
        ld      (state_volume_fade_out), a
        ld      (state_volume_fade_progress), a
        ld      a, #1
        ld      (state_volume_fade_speed), a
        ret


;;; Reset music output levels
;;; ------
;;; [a modified - other registers saved]
volume_reset_music_levels::
        push    bc
        push    de
        push    hl
        ;; disable any ongoing fade out
        ld      a, #0
        ld      (state_volume_fade_out), a
        ld      (state_volume_fade_progress), a
        ld      a, #1
        ld      (state_volume_fade_speed), a
        ;; reset ADPCM-A master attenuation
        ld      a, #0
        ld      (state_volume_adpcm_a_master), a
        ;; reset channels level based on current music level
        call    volume_update_channels_levels
        call    volume_update_ym2610
        pop     hl
        pop     de
        pop     bc
        ret


;;; Reconfigure each channel's output level after the music level
;;; was updated by a volume up/down operation
;;; ------
;;; [a modified - other registers saved]
volume_update_channels_levels:
        push    hl
        push    bc
        ld      a, (state_volume_music_level)
        ld      c, a
        ld      b, #0

        ld      hl, #state_volume_fm_ramp
        add     hl, bc
        ld      a, (hl)
        ld      (state_fm_volume_attenuation), a

        ld      hl, #state_volume_ssg_ramp
        add     hl, bc
        ld      a, (hl)
        ld      (state_ssg_volume_attenuation), a

        ld      hl, #state_volume_adpcm_a_ramp
        add     hl, bc
        ld      a, (hl)
        ld      (state_adpcm_a_volume_attenuation), a

        ld      hl, #state_volume_adpcm_b_ramp
        add     hl, bc
        ld      a, (hl)
        ld      (state_adpcm_b_volume_attenuation), a

        pop     bc
        pop     hl
        ret


;;; Return an interpolated output level from a output level ramp
;;; . The position in the ramp is given by a fixed point level
;;;   (4bit integer + 2bit fractional)
;;; . The output level is the interpolated level between the two
;;;   adjacent integer levels in the ramp
;;; ------
;;; hl: output level ramp
;;; a: fixed point level
;;; [a, bc, de, hl modified]
volume_level_from_ramp::
        ;; bc: 16bit-extended level
        ld      a, (state_volume_fade_progress)
        sra     a
        sra     a
        ld      c, a
        ld      b, #0

        ;; d:  volume distance between level+1 and level
        inc     bc
        add     hl, bc
        ld      d, (hl)
        dec     hl
        ld      a, (hl)
        sub     d
        ld      d, a

        ;; e: intermediate pos between level and level+1 [0..3]
        ld      a, (state_volume_fade_progress)
        and     #0x3
        ld      e, a

        ;; a: pos * distance => result between [0..3*distance]
        ld      a, #0
        bit     0, e
        jr      z, _fade_post_bit0
        add     d
_fade_post_bit0:
        sla     d
        bit     1, e
        jr      z, _fade_post_bit1
        add     d
_fade_post_bit1:
        ;; d: scale distance back to [0..distance]
        sra     a
        sra     a
        ld      d, a

        ;; a: level distance with intermediate distance
        ld      a, (hl)
        sub     d
        ret


;;; Update currently playing notes in the YM2610 to reflect the how
;;; the channels' output levels are currently configured in nullsound
;;; ------
;;; [a, de, bc, hl modified]
volume_update_ym2610:
        ;; d: FM + SSG channels in use
        ld      a, (state_ch_bits)
        ld      d, a
        ;; save the current FM channel context
        ld      a, (state_fm_channel)
        push    af
        ld      a, #0
        ld      (state_fm_channel), a
        ;; Loop over all the FM channels that need to be updated
        ;; e: total number of FM channels to process
        ld      e, #4
_vol_fm_loop:
        ;; channel used in the music?
        bit     0, d
        jr      z, _vol_fm_next
        push    de
        call    fm_ctx_set_current
        call    fm_set_ops_level_for_instr
        pop     de
        ld      a, (state_fm_channel)
_vol_fm_next:
        inc     a
        sra     d
        dec     e
        jr      nz, _vol_fm_loop
        ;; restore the current FM channel context
        pop     af
        call    fm_ctx_set_current

        ;; update SSG channels, no loop here, it's smaller that way
        bit     0, d
        jr      z, _vol_ssg_b
        ld      a, (state_mirrored_ssg_a+PROPS_VOL_OFFSET)
        ld      c, a
        ld      b, #0
        call    ssg_mix_volume
_vol_ssg_b:
        bit     1, d
        jr      z, _vol_ssg_c
        ld      a, (state_mirrored_ssg_b+PROPS_VOL_OFFSET)
        ld      c, a
        ld      b, #1
        call    ssg_mix_volume
_vol_ssg_c:
        bit     2, d
        jr      z, _vol_post_ssg
        ld      a, (state_mirrored_ssg_c+PROPS_VOL_OFFSET)
        ld      c, a
        ld      b, #2
        call    ssg_mix_volume
_vol_post_ssg:

        ;; d: ADPCM channels in use
        ld      a, (state_ch_bits+1)
        ld      d, a

        ;; Loop over all the ADPCM-A channels that need to be updated
        ;; e: total number of FM channels to process
        ld      e, #6
        ld      hl, #state_adpcm_a_vol
_vol_adpcm_a_loop:
        ;; channel used in the music?
        bit     0, d
        jr      z, _vol_adpcm_a_next
        ld      a, (hl)
        or      #0xc0           ; default pan (L+R)
        call    adpcm_a_scale_output
        ld      c, a
        ld      a, #(REG_ADPCM_A1_PAN_VOLUME+6)
        sub     e
        ld      b, a
        call    ym2610_write_port_b
_vol_adpcm_a_next:
        inc     hl
        sra     d
        dec     e
        jr      nz, _vol_adpcm_a_loop

        ;; update ADPCM-A master volume
        ld      a, (state_volume_adpcm_a_master)
        neg
        add     #0x3f
        ld      c, a
        ld      b, #REG_ADPCM_A_MASTER_VOLUME
        call    ym2610_write_port_b

        ;; update ADPCM-B if it is used in the music
        bit     0, d
        jr      z, _vol_post_adpcm_b
        ld      a, (state_adpcm_b_vol)
        call    adpcm_b_scale_output
        ld      c, a
        ld      b, #REG_ADPCM_B_VOLUME
        call    ym2610_write_port_a
_vol_post_adpcm_b:

        ret


;;; Check whether a volume fade out is in progress, update the
;;; channels output levels accordingly
;;; ------
;;; [a modified - other registers saved]
update_volume_state_tracker::
        ld      a, (state_volume_fade_out)
        bit     0, a
        jp      z, _post_volume_fade_out
        ld      a, (state_timer_tick_reached)
        bit     TIMER_CONSUMER_VOLUME_BIT, a
        jp      z, _post_volume_fade_out

        push    hl
        push    bc
        push    de

        ld      hl, #state_volume_fm_ramp
        call    volume_level_from_ramp
        ld      (state_fm_volume_attenuation), a

        ld      hl, #state_volume_ssg_ramp
        call    volume_level_from_ramp
        ld      (state_ssg_volume_attenuation), a

        ;; NOTE: do not update individual ADPCM-A channel for the time
        ;; being. Rely on the global master ADPCM-A
        ;; ld      hl, #state_volume_adpcm_a_ramp
        ;; call    volume_level_from_ramp
        ;; ld      (state_adpcm_a_volume_attenuation), a
        ld      hl, #state_volume_adpcm_a_master_ramp
        call    volume_level_from_ramp
        ld      (state_volume_adpcm_a_master), a

        ld      hl, #state_volume_adpcm_b_ramp
        call    volume_level_from_ramp
        ld      (state_adpcm_b_volume_attenuation), a

        ;; update YM2610
        call    volume_update_ym2610

fade::
        ;; fade progression
        ld      a, (state_volume_fade_speed)
        ld      b, a
        ld      a, (state_volume_fade_progress)
        sub     b
        jp      p, next_fade
        ld      a, #0
        ld      (state_volume_fade_out), a
next_fade::
        ld      (state_volume_fade_progress), a

        res     TIMER_CONSUMER_VOLUME_BIT, a
        pop     de
        pop     bc
        pop     hl

_post_volume_fade_out::
        ret


;;; Raise the current music level by one step
;;; ------
;;; [a modified - other registers saved]
stream_volume_down::
        push    bc
        ld      a, (state_volume_music_level)
        dec     a
        bit     4, a
        jr      nz, _post_vol_down
        ld      (state_volume_music_level), a
_post_vol_down:
        call    volume_update_channels_levels
        call    volume_update_ym2610
        pop     bc
        ret


;;; Raise the current music level by one step
;;; ------
;;; [a modified - other registers saved]
stream_volume_up::
        push    bc
        ld      a, (state_volume_music_level)
        inc     a
        bit     4, a
        jr      nz, _post_vol_up
        ld      (state_volume_music_level), a
_post_vol_up:
        call    volume_update_channels_levels
        call    volume_update_ym2610
        pop     bc
        ret


;;; Fade the music level down to zero
;;; This takes up to 64 ticks in time, when started from the maximum volume
;;; and with the minimum fade speed (0.25 level per tick)
;;; ------
;;; [a modified - other registers saved]
volume_fade_out::
        ;; start the fade out from the current music level
        ld      a, (state_volume_music_level)
        sla     a
        sla     a
        ld      (state_volume_fade_progress), a
        ld      a, #1
        ld      (state_volume_fade_out), a
        ret
