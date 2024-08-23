/*
 * Copyright (c) 2021-2024 Damien Ciabrini
 * This file is part of ngdevkit
 *
 * ngdevkit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * ngdevkit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __NGDEVKIT_NG_DIP_H__
#define __NGDEVKIT_NG_DIP_H__

#include <ngdevkit/types.h>

/*
 * Public helpers and macros
 */

// Configures a time DIP
typedef struct {
    u8 min;
    u8 sec;
} dip_time_t;

// Configures an enum DIP
// At runtime, only the `selected` part is available in RAM
typedef struct {
    u8 selected:4;
    u8 length:4;
} dip_enum_t;

// padded string type for software DIP
typedef struct { char s[12]; } dip_str12_t;

// padded string type for ROM name
typedef struct { char s[16]; } dip_str16_t;

// The software DIP configuration for this ROM
typedef struct _rom_dip {
    // ROM name
    dip_str16_t name;
    // Up to two time DIPs allowed by the BIOS for this ROM
    // unused time DIPs are marked as { 0xff, 0xff }
    dip_time_t time_dips[2];
    // Up to two integer DIPs allowed by the BIOS for this ROM
    // 0 presented by the BIOS as "UNUSED", 100 as "INFINITE"
    u8 int_dips[2];
    // Up to ten enum DIPs allowed by the BIOS for this ROM
    // an enum DIP has up to 16 possible values (4bits), and
    // a initial value for the Backup RAM (4bits)
    dip_enum_t enum_dips[10];
    // List of description strings for each DIP used in this ROM
    dip_str12_t strings[];
} rom_dip_t;


// On MVS, the 14 differents software DIP are available
// in RAM (total 16 bytes). Those helpers let you access
// every type of software DIP as an array.
// Time DIP, 2 items
#define DIP_TIME ((dip_time_t*)&bios_game_dip[0])
// Integer DIP, 2 items
#define DIP_INT ((u8*)&bios_game_dip[4])
// Enum DIP, 10 items
#define DIP_ENUM ((u8*)&bios_game_dip[6])


/*
 * Software DIP config generator
 * =============================
 *
 * This macro expects three user-defined macro that
 * specify all the software DIP that the game is using.
 * The macros have to be defined before including this
 * header file. The syntax is as follows:
 *
 *   #define DIP_TIME_OPTS(opt)                    \
 *       opt(0,"ROUND TIME", 0x02, 0x30)
 *
 *   #define DIP_INT_OPTS(opt)                     \
 *       opt(0,"STAMINA", 20)                      \
 *       opt(1,"RESPAWN", 3)
 *
 *   #define DIP_ENUM_OPTS(opt)                    \
 *       opt(0, "ANIMAL", ("CAT","DOG","PONY"), 2) \
 *       opt(1, "VARIANT", ("SLOW","FAST"), 1)
 *
 *   #include <ngdevkit/soft-dip.h>
 *   GENERATE_DIP(jp, "ROM NAME")
 *   GENERATE_DIP(us, "ROM NAME")
 *   GENERATE_DIP(eu, "ROM NAME")
 *
 * Each macro returns a space-separated list of DIP
 * used by the game. Each DIP item has the following
 * format:
 *    opt( 0,      <- DIP index (has to be a number)
 *         "NAME", <- DIP name (max 12 bytes string)
 *         ... args ...)
 *
 * Time DIP - args format:
 *    <u8>,  <- minutes
 *    <u8>   <- seconds
 *
 * Int DIP - args format:
 *    <u8>   <- value
 *
 * Enum DIP - args format:
 *    (<str12>, <str12>, ...),  <- possible values
 *    <u8>                      <- default value
 *
 * Note: if the ROM has different DIP based on
 * region, you must define macros with the proper
 * suffix, e.g:
 *    #define DIP_INT_OPTS_jp(opt) opt(0, 42)
 */

#define GENERATE_DIP(region, game)                                      \
    const rom_dip_t dip_##region##_rom _SECTION = {                     \
        .name = _PAD16(game),                                           \
        .time_dips = {                                                  \
            [0 ... 1] = {0xff, 0xff}                                    \
            DIP_TIME_OPTS_##region(_TIME_CFG)                           \
        },                                                              \
        .int_dips = {                                                   \
            [0 ... 1] = 0xff                                            \
            DIP_INT_OPTS_##region(_INT_CFG)                             \
        },                                                              \
        .enum_dips = {                                                  \
            [0 ... 9] = {0, 0}                                          \
            DIP_ENUM_OPTS_##region(_ENUM_CFG)                           \
        }                                                               \
        _DIP_STRINGS_PRE_##region                                       \
        DIP_TIME_OPTS_##region(_TIME_STR) _DIP_TIME_SEPARATOR_##region  \
        DIP_INT_OPTS_##region(_INT_STR)   _DIP_INT_SEPARATOR_##region   \
        DIP_ENUM_OPTS_##region(_ENUM_STR)                               \
        _DIP_STRINGS_POST_##region                                      \
}

// Software DIP configuration for the JP region
extern const rom_dip_t dip_jp_rom;

// Software DIP configuration for the US region
extern const rom_dip_t dip_us_rom;

// Software DIP configuration for the EU region
extern const rom_dip_t dip_eu_rom;


// Types of software DIPs supported by the BIOS
typedef enum dip_type { DIP_TYPE_TIME, DIP_TYPE_INT, DIP_TYPE_ENUM } dip_type_t;

// Get the name of a DIP configured for this ROM
extern const dip_str12_t* bios_dip_name(u8 region, dip_type_t type, u8 num);

// Get the current value of an enum DIP as configured in backup RAM
extern const dip_str12_t* bios_dip_enum_choices(u8 region, u8 num);



/*
 * Private macros to generate DIP data at compile-time
 */

// The DIP data end up in a specific section to ease linking
#define _SECTION __attribute__((section(".text.softdip")))

/* Visitor macros */
// Time DIP setting
#define _TIME_CFG(num,title,minutes,seconds)  , [num] = {minutes, seconds}
// Integer DIP setting
#define _INT_CFG(num,title,value)             , [num] = value
// Enum DIP setting
#define _ENUM_CFG(num,title,choices,selected) , [num] = {selected, _FLAT_LIST_LEN choices}

// Time DIP description
#define _TIME_STR(num,title,minutes,seconds) _DIP_STR_##num(title)
// Integer DIP description
#define _INT_STR(num,title,value) _DIP_STR_##num(title)
// Enum DIP description
#define _ENUM_STR(num,title,choices,selected) _DIP_ENUM_STR_##num(num,title,choices,selected)

// length of an arbitrary long array of elements
// _LIST_LEN(,a ,b ,c) -> 3
// _LIST_LEN() -> 0
#define _LIST_LEN(...) _GET_NTH_ARG_GUARDS(start __VA_ARGS__ , end,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0)
#define _GET_NTH_ARG_GUARDS(start, end, _1, _2, _3, _4, _5, _6, _7, _9, _10, _11, _12, _13, _14, _15, N, ...) N
#define _FLAT_LIST_LEN(...) _LIST_LEN(,__VA_ARGS__)
#define _TO_ITEM(...) , item

// macros used to iterate over the simple time and integer DIPs
#define _DIP_STR_0(title) _PAD12(title)
#define _DIP_STR_1 , _DIP_STR_0

// macros used to iterate over the enum types and its arbitrary-length
// array of strings. outputs a list of space-padded 12-bytes strings
#define _DIP_ENUM_STR_0(num,title,choices,selected) _PAD12(title) _MAP_PAD12(choices)
#define _DIP_ENUM_STR_1 , _DIP_ENUM_STR_0
#define _DIP_ENUM_STR_2 , _DIP_ENUM_STR_0
#define _DIP_ENUM_STR_3 , _DIP_ENUM_STR_0
#define _DIP_ENUM_STR_4 , _DIP_ENUM_STR_0
#define _DIP_ENUM_STR_5 , _DIP_ENUM_STR_0
#define _DIP_ENUM_STR_6 , _DIP_ENUM_STR_0
#define _DIP_ENUM_STR_7 , _DIP_ENUM_STR_0
#define _DIP_ENUM_STR_8 , _DIP_ENUM_STR_0
#define _DIP_ENUM_STR_9 , _DIP_ENUM_STR_0

// macros to iterate over an arbitrary-length array of strings
// and return an array of space-padded 12-bytes strings
#define _MAP_1(x)      ,_PAD12(x)
#define _MAP_2(x,...)  ,_PAD12(x) _MAP_1(__VA_ARGS__)
#define _MAP_3(x,...)  ,_PAD12(x) _MAP_2(__VA_ARGS__)
#define _MAP_4(x,...)  ,_PAD12(x) _MAP_3(__VA_ARGS__)
#define _MAP_5(x,...)  ,_PAD12(x) _MAP_4(__VA_ARGS__)
#define _MAP_6(x,...)  ,_PAD12(x) _MAP_5(__VA_ARGS__)
#define _MAP_7(x,...)  ,_PAD12(x) _MAP_6(__VA_ARGS__)
#define _MAP_8(x,...)  ,_PAD12(x) _MAP_7(__VA_ARGS__)
#define _MAP_9(x,...)  ,_PAD12(x) _MAP_8(__VA_ARGS__)
#define _MAP_10(x,...) ,_PAD12(x) _MAP_9(__VA_ARGS__)
#define _MAP_11(x,...) ,_PAD12(x) _MAP_10(__VA_ARGS__)
#define _MAP_12(x,...) ,_PAD12(x) _MAP_11(__VA_ARGS__)
#define _MAP_13(x,...) ,_PAD12(x) _MAP_12(__VA_ARGS__)
#define _MAP_14(x,...) ,_PAD12(x) _MAP_13(__VA_ARGS__)
#define _MAP_15(x,...) ,_PAD12(x) _MAP_14(__VA_ARGS__)

#define _MAP_N(list,n) _MAP_##n list
#define _APPLY_MAP_N(...) _MAP_N(__VA_ARGS__)

#define _MAP_PAD12(x) _APPLY_MAP_N(x,_FLAT_LIST_LEN x)

// Disable automatic padding (for debugging purpose only)
#ifndef _DIP_NO_PADDING_

// Convert a C string to a 12-bytes, space-padded data (non null terminated)
#define _PAD12(x) (__builtin_choose_expr(sizeof(x)==13,(dip_str12_t){.s=x},(dip_str12_t){.s=x, .s[sizeof(x)==13?1:sizeof(x)-1 ... 11] = ' '}))
// Convert a C string to a 16-bytes, space-padded data (non null terminated)
#define _PAD16(x) (__builtin_choose_expr(sizeof(x)==17,(dip_str16_t){.s=x},(dip_str16_t){.s=x, .s[sizeof(x)==17?1:sizeof(x)-1 ... 15] = ' '}))

#else

#define _PAD16(str) (dip_str16_t){.s = str}
#define _PAD12(str) (dip_str12_t){.s = str}

#endif


/*
 * Macros configuration based on DIP settings for every region
 */

// When DIP definition are not provided, use default empty ones.
#ifndef DIP_TIME_OPTS
#define DIP_TIME_OPTS(x)
#endif

#ifndef DIP_INT_OPTS
#define DIP_INT_OPTS(x)
#endif

#ifndef DIP_ENUM_OPTS
#define DIP_ENUM_OPTS(x)
#endif


// When region-specific DIP definition are not provided, fallback
// to the generic ones
#ifndef DIP_TIME_OPTS_jp
#define DIP_TIME_OPTS_jp DIP_TIME_OPTS
#endif
#ifndef DIP_INT_OPTS_jp
#define DIP_INT_OPTS_jp DIP_INT_OPTS
#endif
#ifndef DIP_ENUM_OPTS_jp
#define DIP_ENUM_OPTS_jp DIP_ENUM_OPTS
#endif

#ifndef DIP_TIME_OPTS_us
#define DIP_TIME_OPTS_us DIP_TIME_OPTS
#endif
#ifndef DIP_INT_OPTS_us
#define DIP_INT_OPTS_us DIP_INT_OPTS
#endif
#ifndef DIP_ENUM_OPTS_us
#define DIP_ENUM_OPTS_us DIP_ENUM_OPTS
#endif

#ifndef DIP_TIME_OPTS_eu
#define DIP_TIME_OPTS_eu DIP_TIME_OPTS
#endif
#ifndef DIP_INT_OPTS_eu
#define DIP_INT_OPTS_eu DIP_INT_OPTS
#endif
#ifndef DIP_ENUM_OPTS_eu
#define DIP_ENUM_OPTS_eu DIP_ENUM_OPTS
#endif

// DIP macros configuration for the US region

// detects which DIP are used for this region
#if _LIST_LEN(DIP_TIME_OPTS_jp(_TO_ITEM)) != 0
#define DIP_TIME_USED_jp 1
#endif
#if _LIST_LEN(DIP_INT_OPTS_jp(_TO_ITEM)) != 0
#define DIP_INT_USED_jp 1
#endif
#if _LIST_LEN(DIP_ENUM_OPTS_jp(_TO_ITEM)) != 0
#define DIP_ENUM_USED_jp 1
#endif

// If at least one DIP is defined, we have to emit the optional strings
// field in the DIP structure
#if defined(DIP_TIME_USED_jp) || defined(DIP_INT_USED_jp) || defined(DIP_ENUM_USED_jp)
#define _DIP_STRINGS_PRE_jp , .strings = {
#define _DIP_STRINGS_POST_jp }
#else
#define _DIP_STRINGS_PRE_jp
#define _DIP_STRINGS_POST_jp
#endif

// Use a comma to separate optional DIP strings when necessary
#if defined(DIP_TIME_USED_jp) && (defined(DIP_INT_USED_jp) || defined(DIP_ENUM_USED_jp))
#define _DIP_TIME_SEPARATOR_jp ,
#else
#define _DIP_TIME_SEPARATOR_jp
#endif
#if defined(DIP_INT_USED_jp) && defined(DIP_ENUM_USED_jp)
#define _DIP_INT_SEPARATOR_jp ,
#else
#define _DIP_INT_SEPARATOR_jp
#endif

// Similar DIP macros configuration for the US region

#if _LIST_LEN(DIP_TIME_OPTS_us(_TO_ITEM)) != 0
#define DIP_TIME_USED_us 1
#endif
#if _LIST_LEN(DIP_INT_OPTS_us(_TO_ITEM)) != 0
#define DIP_INT_USED_us 1
#endif
#if _LIST_LEN(DIP_ENUM_OPTS_us(_TO_ITEM)) != 0
#define DIP_ENUM_USED_us 1
#endif

#if defined(DIP_TIME_USED_us) || defined(DIP_INT_USED_us) || defined(DIP_ENUM_USED_us)
#define _DIP_STRINGS_PRE_us , .strings = {
#define _DIP_STRINGS_POST_us }
#else
#define _DIP_STRINGS_PRE_us
#define _DIP_STRINGS_POST_us
#endif

#if defined(DIP_TIME_USED_us) && (defined(DIP_INT_USED_us) || defined(DIP_ENUM_USED_us))
#define _DIP_TIME_SEPARATOR_us ,
#else
#define _DIP_TIME_SEPARATOR_us
#endif
#if defined(DIP_INT_USED_us) && defined(DIP_ENUM_USED_us)
#define _DIP_INT_SEPARATOR_us ,
#else
#define _DIP_INT_SEPARATOR_us
#endif

// Similar DIP macros configuration for the EU region

#if _LIST_LEN(DIP_TIME_OPTS_eu(_TO_ITEM)) != 0
#define DIP_TIME_USED_eu 1
#endif
#if _LIST_LEN(DIP_INT_OPTS_eu(_TO_ITEM)) != 0
#define DIP_INT_USED_eu 1
#endif
#if _LIST_LEN(DIP_ENUM_OPTS_eu(_TO_ITEM)) != 0
#define DIP_ENUM_USED_eu 1
#endif

#if defined(DIP_TIME_USED_eu) || defined(DIP_INT_USED_eu) || defined(DIP_ENUM_USED_eu)
#define _DIP_STRINGS_PRE_eu , .strings = {
#define _DIP_STRINGS_POST_eu }
#else
#define _DIP_STRINGS_PRE_eu
#define _DIP_STRINGS_POST_eu
#endif

#if defined(DIP_TIME_USED_eu) && (defined(DIP_INT_USED_eu) || defined(DIP_ENUM_USED_eu))
#define _DIP_TIME_SEPARATOR_eu ,
#else
#define _DIP_TIME_SEPARATOR_eu
#endif
#if defined(DIP_INT_USED_eu) && defined(DIP_ENUM_USED_eu)
#define _DIP_INT_SEPARATOR_eu ,
#else
#define _DIP_INT_SEPARATOR_eu
#endif

/*
 * Macro for support of old/deprecated symbol-based DIP access
 */

#define dip_jp_time_0_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_TIME, 0)
#define dip_jp_time_1_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_TIME, 1)
#define dip_jp_int_0_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_INT, 0)
#define dip_jp_int_1_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_INT, 1)
#define dip_jp_enum_0_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 0)
#define dip_jp_enum_1_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 1)
#define dip_jp_enum_2_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 2)
#define dip_jp_enum_3_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 3)
#define dip_jp_enum_4_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 4)
#define dip_jp_enum_5_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 5)
#define dip_jp_enum_6_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 6)
#define dip_jp_enum_7_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 7)
#define dip_jp_enum_8_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 8)
#define dip_jp_enum_9_name bios_dip_name(BIOS_COUNTRY_JP, DIP_TYPE_ENUM, 9)
#define dip_jp_enum_0_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 0)
#define dip_jp_enum_1_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 1)
#define dip_jp_enum_2_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 2)
#define dip_jp_enum_3_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 3)
#define dip_jp_enum_4_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 4)
#define dip_jp_enum_5_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 5)
#define dip_jp_enum_6_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 6)
#define dip_jp_enum_7_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 7)
#define dip_jp_enum_8_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 8)
#define dip_jp_enum_9_choice &bios_dip_enum_choices(BIOS_COUNTRY_JP, 9)

#define dip_us_time_0_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_TIME, 0)
#define dip_us_time_1_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_TIME, 1)
#define dip_us_int_0_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_INT, 0)
#define dip_us_int_1_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_INT, 1)
#define dip_us_enum_0_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 0)
#define dip_us_enum_1_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 1)
#define dip_us_enum_2_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 2)
#define dip_us_enum_3_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 3)
#define dip_us_enum_4_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 4)
#define dip_us_enum_5_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 5)
#define dip_us_enum_6_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 6)
#define dip_us_enum_7_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 7)
#define dip_us_enum_8_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 8)
#define dip_us_enum_9_name bios_dip_name(BIOS_COUNTRY_US, DIP_TYPE_ENUM, 9)
#define dip_us_enum_0_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 0)
#define dip_us_enum_1_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 1)
#define dip_us_enum_2_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 2)
#define dip_us_enum_3_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 3)
#define dip_us_enum_4_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 4)
#define dip_us_enum_5_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 5)
#define dip_us_enum_6_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 6)
#define dip_us_enum_7_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 7)
#define dip_us_enum_8_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 8)
#define dip_us_enum_9_choice &bios_dip_enum_choices(BIOS_COUNTRY_US, 9)

#define dip_eu_time_0_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_TIME, 0)
#define dip_eu_time_1_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_TIME, 1)
#define dip_eu_int_0_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_INT, 0)
#define dip_eu_int_1_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_INT, 1)
#define dip_eu_enum_0_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 0)
#define dip_eu_enum_1_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 1)
#define dip_eu_enum_2_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 2)
#define dip_eu_enum_3_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 3)
#define dip_eu_enum_4_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 4)
#define dip_eu_enum_5_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 5)
#define dip_eu_enum_6_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 6)
#define dip_eu_enum_7_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 7)
#define dip_eu_enum_8_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 8)
#define dip_eu_enum_9_name bios_dip_name(BIOS_COUNTRY_EU, DIP_TYPE_ENUM, 9)
#define dip_eu_enum_0_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 0)
#define dip_eu_enum_1_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 1)
#define dip_eu_enum_2_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 2)
#define dip_eu_enum_3_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 3)
#define dip_eu_enum_4_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 4)
#define dip_eu_enum_5_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 5)
#define dip_eu_enum_6_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 6)
#define dip_eu_enum_7_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 7)
#define dip_eu_enum_8_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 8)
#define dip_eu_enum_9_choice &bios_dip_enum_choices(BIOS_COUNTRY_EU, 9)


#endif /* __NGDEVKIT_NG_DIP_H__ */
