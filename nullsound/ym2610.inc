;;; nullsound - modular sound driver
;;; Copyright (c) 2020-2023 Damien Ciabrini
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

;;; The following macros are based on doc found on neogeodev wiki
;;; https://wiki.neogeodev.org/index.php?title=YM2610_registers


;;; FM
;;; These macros are meant to be used with Z80 port 4 and port 5
        .equ    REG_FM_LFO_CONTROL,                     0x22
        .equ    REG_FM_KEY_ON_OFF_OPS,                  0x28

;;; FM channel 1
;;; These macros are meant to be used with Z80 port 4 and port 5
        .equ    REG_FM1_OP1_DETUNE_MULTIPLY,            0x31
        .equ    REG_FM1_OP3_DETUNE_MULTIPLY,            0x35
        .equ    REG_FM1_OP2_DETUNE_MULTIPLY,            0x39
        .equ    REG_FM1_OP4_DETUNE_MULTIPLY,            0x3d
        .equ    REG_FM1_OP1_TOTAL_LEVEL,                0x41
        .equ    REG_FM1_OP3_TOTAL_LEVEL,                0x45
        .equ    REG_FM1_OP2_TOTAL_LEVEL,                0x49
        .equ    REG_FM1_OP4_TOTAL_LEVEL,                0x4d
        .equ    REG_FM1_OP1_KEY_SCALE_ATTACK_RATE,      0x51
        .equ    REG_FM1_OP3_KEY_SCALE_ATTACK_RATE,      0x55
        .equ    REG_FM1_OP2_KEY_SCALE_ATTACK_RATE,      0x59
        .equ    REG_FM1_OP4_KEY_SCALE_ATTACK_RATE,      0x5d
        .equ    REG_FM1_OP1_AM_ON_DECAY_RATE,           0x61
        .equ    REG_FM1_OP3_AM_ON_DECAY_RATE,           0x65
        .equ    REG_FM1_OP2_AM_ON_DECAY_RATE,           0x69
        .equ    REG_FM1_OP4_AM_ON_DECAY_RATE,           0x6d
        .equ    REG_FM1_OP1_SUSTAIN_RATE,               0x71
        .equ    REG_FM1_OP3_SUSTAIN_RATE,               0x75
        .equ    REG_FM1_OP2_SUSTAIN_RATE,               0x79
        .equ    REG_FM1_OP4_SUSTAIN_RATE,               0x7d
        .equ    REG_FM1_OP1_SUSTAIN_LEVEL_RELEASE_RATE, 0x81
        .equ    REG_FM1_OP3_SUSTAIN_LEVEL_RELEASE_RATE, 0x85
        .equ    REG_FM1_OP2_SUSTAIN_LEVEL_RELEASE_RATE, 0x89
        .equ    REG_FM1_OP4_SUSTAIN_LEVEL_RELEASE_RATE, 0x8d
        .equ    REG_FM1_OP1_SSG_EG,                     0x91
        .equ    REG_FM1_OP3_SSG_EG,                     0x95
        .equ    REG_FM1_OP2_SSG_EG,                     0x99
        .equ    REG_FM1_OP4_SSG_EG,                     0x9d
        .equ    REG_FM1_FNUM_1,                         0xa1
        .equ    REG_FM1_BLOCK_FNUM_2,                   0xa5
        .equ    REG_FM1_FEEDBACK_ALGORITHM,             0xb1
        .equ    REG_FM1_L_R_AMSENSE_PMSENSE,            0xb5

;;; FM channel 2
;;; These macros are meant to be used with Z80 port 4 and port 5
        .equ    REG_FM2_OP1_DETUNE_MULTIPLY,            0x32
        .equ    REG_FM2_OP3_DETUNE_MULTIPLY,            0x36
        .equ    REG_FM2_OP2_DETUNE_MULTIPLY,            0x3a
        .equ    REG_FM2_OP4_DETUNE_MULTIPLY,            0x3e
        .equ    REG_FM2_OP1_TOTAL_LEVEL,                0x42
        .equ    REG_FM2_OP3_TOTAL_LEVEL,                0x46
        .equ    REG_FM2_OP2_TOTAL_LEVEL,                0x4a
        .equ    REG_FM2_OP4_TOTAL_LEVEL,                0x4e
        .equ    REG_FM2_OP1_KEY_SCALE_ATTACK_RATE,      0x52
        .equ    REG_FM2_OP3_KEY_SCALE_ATTACK_RATE,      0x56
        .equ    REG_FM2_OP2_KEY_SCALE_ATTACK_RATE,      0x5a
        .equ    REG_FM2_OP4_KEY_SCALE_ATTACK_RATE,      0x5e
        .equ    REG_FM2_OP1_AM_ON_DECAY_RATE,           0x62
        .equ    REG_FM2_OP3_AM_ON_DECAY_RATE,           0x66
        .equ    REG_FM2_OP2_AM_ON_DECAY_RATE,           0x6a
        .equ    REG_FM2_OP4_AM_ON_DECAY_RATE,           0x6e
        .equ    REG_FM2_OP1_SUSTAIN_RATE,               0x72
        .equ    REG_FM2_OP3_SUSTAIN_RATE,               0x76
        .equ    REG_FM2_OP2_SUSTAIN_RATE,               0x7a
        .equ    REG_FM2_OP4_SUSTAIN_RATE,               0x7e
        .equ    REG_FM2_OP1_SUSTAIN_LEVEL_RELEASE_RATE, 0x82
        .equ    REG_FM2_OP3_SUSTAIN_LEVEL_RELEASE_RATE, 0x86
        .equ    REG_FM2_OP2_SUSTAIN_LEVEL_RELEASE_RATE, 0x8a
        .equ    REG_FM2_OP4_SUSTAIN_LEVEL_RELEASE_RATE, 0x8e
        .equ    REG_FM2_OP1_SSG_EG,                     0x92
        .equ    REG_FM2_OP3_SSG_EG,                     0x96
        .equ    REG_FM2_OP2_SSG_EG,                     0x9a
        .equ    REG_FM2_OP4_SSG_EG,                     0x9e
        .equ    REG_FM2_FNUM_1,                         0xa2
        .equ    REG_FM2_BLOCK_FNUM_2,                   0xa6
        .equ    REG_FM2_FEEDBACK_ALGORITHM,             0xb2
        .equ    REG_FM2_L_R_AMSENSE_PMSENSE,            0xb6

;;; FM channel 3
;;; These macros are meant to be used with Z80 port 6 and port 7
        .equ    REG_FM3_OP1_DETUNE_MULTIPLY,            0x31
        .equ    REG_FM3_OP3_DETUNE_MULTIPLY,            0x35
        .equ    REG_FM3_OP2_DETUNE_MULTIPLY,            0x39
        .equ    REG_FM3_OP4_DETUNE_MULTIPLY,            0x3d
        .equ    REG_FM3_OP1_TOTAL_LEVEL,                0x41
        .equ    REG_FM3_OP3_TOTAL_LEVEL,                0x45
        .equ    REG_FM3_OP2_TOTAL_LEVEL,                0x49
        .equ    REG_FM3_OP4_TOTAL_LEVEL,                0x4d
        .equ    REG_FM3_OP1_KEY_SCALE_ATTACK_RATE,      0x51
        .equ    REG_FM3_OP3_KEY_SCALE_ATTACK_RATE,      0x55
        .equ    REG_FM3_OP2_KEY_SCALE_ATTACK_RATE,      0x59
        .equ    REG_FM3_OP4_KEY_SCALE_ATTACK_RATE,      0x5d
        .equ    REG_FM3_OP1_AM_ON_DECAY_RATE,           0x61
        .equ    REG_FM3_OP3_AM_ON_DECAY_RATE,           0x65
        .equ    REG_FM3_OP2_AM_ON_DECAY_RATE,           0x69
        .equ    REG_FM3_OP4_AM_ON_DECAY_RATE,           0x6d
        .equ    REG_FM3_OP1_SUSTAIN_RATE,               0x71
        .equ    REG_FM3_OP3_SUSTAIN_RATE,               0x75
        .equ    REG_FM3_OP2_SUSTAIN_RATE,               0x79
        .equ    REG_FM3_OP4_SUSTAIN_RATE,               0x7d
        .equ    REG_FM3_OP1_SUSTAIN_LEVEL_RELEASE_RATE, 0x81
        .equ    REG_FM3_OP3_SUSTAIN_LEVEL_RELEASE_RATE, 0x85
        .equ    REG_FM3_OP2_SUSTAIN_LEVEL_RELEASE_RATE, 0x89
        .equ    REG_FM3_OP4_SUSTAIN_LEVEL_RELEASE_RATE, 0x8d
        .equ    REG_FM3_OP1_SSG_EG,                     0x91
        .equ    REG_FM3_OP3_SSG_EG,                     0x95
        .equ    REG_FM3_OP2_SSG_EG,                     0x99
        .equ    REG_FM3_OP4_SSG_EG,                     0x9d
        .equ    REG_FM3_FNUM_1,                         0xa1
        .equ    REG_FM3_BLOCK_FNUM_2,                   0xa5
        .equ    REG_FM3_FEEDBACK_ALGORITHM,             0xb1
        .equ    REG_FM3_L_R_AMSENSE_PMSENSE,            0xb5

;;; FM channel 4
;;; These macros are meant to be used with Z80 port 6 and port 7
        .equ    REG_FM4_OP1_DETUNE_MULTIPLY,            0x32
        .equ    REG_FM4_OP3_DETUNE_MULTIPLY,            0x36
        .equ    REG_FM4_OP2_DETUNE_MULTIPLY,            0x3a
        .equ    REG_FM4_OP4_DETUNE_MULTIPLY,            0x3e
        .equ    REG_FM4_OP1_TOTAL_LEVEL,                0x42
        .equ    REG_FM4_OP3_TOTAL_LEVEL,                0x46
        .equ    REG_FM4_OP2_TOTAL_LEVEL,                0x4a
        .equ    REG_FM4_OP4_TOTAL_LEVEL,                0x4e
        .equ    REG_FM4_OP1_KEY_SCALE_ATTACK_RATE,      0x52
        .equ    REG_FM4_OP3_KEY_SCALE_ATTACK_RATE,      0x56
        .equ    REG_FM4_OP2_KEY_SCALE_ATTACK_RATE,      0x5a
        .equ    REG_FM4_OP4_KEY_SCALE_ATTACK_RATE,      0x5e
        .equ    REG_FM4_OP1_AM_ON_DECAY_RATE,           0x62
        .equ    REG_FM4_OP3_AM_ON_DECAY_RATE,           0x66
        .equ    REG_FM4_OP2_AM_ON_DECAY_RATE,           0x6a
        .equ    REG_FM4_OP4_AM_ON_DECAY_RATE,           0x6e
        .equ    REG_FM4_OP1_SUSTAIN_RATE,               0x72
        .equ    REG_FM4_OP3_SUSTAIN_RATE,               0x76
        .equ    REG_FM4_OP2_SUSTAIN_RATE,               0x7a
        .equ    REG_FM4_OP4_SUSTAIN_RATE,               0x7e
        .equ    REG_FM4_OP1_SUSTAIN_LEVEL_RELEASE_RATE, 0x82
        .equ    REG_FM4_OP3_SUSTAIN_LEVEL_RELEASE_RATE, 0x86
        .equ    REG_FM4_OP2_SUSTAIN_LEVEL_RELEASE_RATE, 0x8a
        .equ    REG_FM4_OP4_SUSTAIN_LEVEL_RELEASE_RATE, 0x8e
        .equ    REG_FM4_OP1_SSG_EG,                     0x92
        .equ    REG_FM4_OP3_SSG_EG,                     0x96
        .equ    REG_FM4_OP2_SSG_EG,                     0x9a
        .equ    REG_FM4_OP4_SSG_EG,                     0x9e
        .equ    REG_FM4_FNUM_1,                         0xa2
        .equ    REG_FM4_BLOCK_FNUM_2,                   0xa6
        .equ    REG_FM4_FEEDBACK_ALGORITHM,             0xb2
        .equ    REG_FM4_L_R_AMSENSE_PMSENSE,            0xb6


;;; ADPCM playback status
;;; These macros are meant to be used with Z80 port 4 and port 5
        .equ    REG_ADPCM_PLAYBACK_MASK,     0x1c

;;; ADPCM-A
;;; These macros are meant to be used with Z80 port 6 and port 7
        .equ    REG_ADPCM_A_START_STOP,      0x00
        .equ    REG_ADPCM_A_MASTER_VOLUME,   0x01
        .equ    REG_ADPCM_A_RESERVED,        0x02

        .equ    REG_ADPCM_A1_PAN_VOLUME,     0x08
        .equ    REG_ADPCM_A2_PAN_VOLUME,     0x09
        .equ    REG_ADPCM_A3_PAN_VOLUME,     0x0a
        .equ    REG_ADPCM_A4_PAN_VOLUME,     0x0b
        .equ    REG_ADPCM_A5_PAN_VOLUME,     0x0c
        .equ    REG_ADPCM_A6_PAN_VOLUME,     0x0d

        .equ    REG_ADPCM_A1_ADDR_START_LSB, 0x10
        .equ    REG_ADPCM_A2_ADDR_START_LSB, 0x11
        .equ    REG_ADPCM_A3_ADDR_START_LSB, 0x12
        .equ    REG_ADPCM_A4_ADDR_START_LSB, 0x13
        .equ    REG_ADPCM_A5_ADDR_START_LSB, 0x14
        .equ    REG_ADPCM_A6_ADDR_START_LSB, 0x15

        .equ    REG_ADPCM_A1_ADDR_START_MSB, 0x18
        .equ    REG_ADPCM_A2_ADDR_START_MSB, 0x19
        .equ    REG_ADPCM_A3_ADDR_START_MSB, 0x1a
        .equ    REG_ADPCM_A4_ADDR_START_MSB, 0x1b
        .equ    REG_ADPCM_A5_ADDR_START_MSB, 0x1c
        .equ    REG_ADPCM_A6_ADDR_START_MSB, 0x1d

        .equ    REG_ADPCM_A1_ADDR_STOP_LSB,  0x20
        .equ    REG_ADPCM_A2_ADDR_STOP_LSB,  0x21
        .equ    REG_ADPCM_A3_ADDR_STOP_LSB,  0x22
        .equ    REG_ADPCM_A4_ADDR_STOP_LSB,  0x23
        .equ    REG_ADPCM_A5_ADDR_STOP_LSB,  0x24
        .equ    REG_ADPCM_A6_ADDR_STOP_LSB,  0x25

        .equ    REG_ADPCM_A1_ADDR_STOP_MSB,  0x28
        .equ    REG_ADPCM_A2_ADDR_STOP_MSB,  0x29
        .equ    REG_ADPCM_A3_ADDR_STOP_MSB,  0x2a
        .equ    REG_ADPCM_A4_ADDR_STOP_MSB,  0x2b
        .equ    REG_ADPCM_A5_ADDR_STOP_MSB,  0x2c
        .equ    REG_ADPCM_A6_ADDR_STOP_MSB,  0x2d


;;; ADPCM-B
;;; These macros are meant to be used with Z80 port 4 and port 5
        .equ    REG_ADPCM_B_START_STOP,      0x10
        .equ    REG_ADPCM_B_PAN,             0x11

        .equ    REG_ADPCM_B_ADDR_START_LSB,  0x12
        .equ    REG_ADPCM_B_ADDR_START_MSB,  0x13
        .equ    REG_ADPCM_B_ADDR_STOP_LSB,   0x14
        .equ    REG_ADPCM_B_ADDR_STOP_MSB,   0x15

        .equ    REG_ADPCM_B_DELTA_N_LSB,     0x19
        .equ    REG_ADPCM_B_DELTA_N_MSB,     0x1a

        .equ    REG_ADPCM_B_VOLUME,          0x1b


;;; TIMERS
;;; These macros are meant to be used with Z80 port 4 and port 5
        .equ    REG_TIMER_A_COUNTER_MSB,     0x24
        .equ    REG_TIMER_A_COUNTER_LSB,     0x25
        .equ    REG_TIMER_B_COUNTER,         0x26
        .equ    REG_TIMER_FLAGS,             0x27


;;; SSG
;;; These macros are meant to be used with Z80 port 4 and port 5
        .equ    REG_SSG_A_FINE_TUNE,    0x00
        .equ    REG_SSG_A_COARSE_TUNE,  0x01
        .equ    REG_SSG_B_FINE_TUNE,    0x02
        .equ    REG_SSG_B_COARSE_TUNE,  0x03
        .equ    REG_SSG_C_FINE_TUNE,    0x04
        .equ    REG_SSG_C_COARSE_TUNE,  0x05
        .equ    REG_SSG_ENABLE,         0x07
        .equ    REG_SSG_A_VOLUME,       0x08
        .equ    REG_SSG_B_VOLUME,       0x09
        .equ    REG_SSG_C_VOLUME,       0x0a
