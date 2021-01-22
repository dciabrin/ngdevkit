/*
 * Copyright (c) 2021 Damien Ciabrini
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


// On MVS, the 14 differents software DIP are available
// in RAM (total 16 bytes). Those helpers let you access
// every type of software DIP as an array.
// Time DIP, 2 items
#define DIP_TIME ((dip_time_t*)&bios_game_dip[0])
// Integer DIP, 2 items
#define DIP_INT  ((u8*)&bios_game_dip[4])
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
 * country, you must define macros with the proper
 * suffix, e.g:
 *    #define DIP_INT_OPTS_jp(opt) opt(0, 42)
 */

#define GENERATE_DIP(label,name)                                        \
    const u8 dip_##label##_rom[16] _SECTION = _PAD16(name);             \
    const dip_time_t dip_##label##_time[2] _SECTION = {                 \
        {0xff, 0xff}, {0xff, 0xff}                                      \
        DIP_TIME_OPTS_##label(_TIME_CFG)                                \
    };                                                                  \
    const u8 dip_##label##_int[2] _SECTION = {                          \
        0xff, 0xff                                                      \
        DIP_INT_OPTS_##label(_INT_CFG)                                  \
    };                                                                  \
    const dip_enum_t dip_##label##_enum[10] _SECTION = {                \
        {0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0},                         \
        {0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0}                          \
        DIP_ENUM_OPTS_##label(_ENUM_CFG)                                \
    };                                                                  \
    DIP_TIME_OPTS_##label(_TIME_STR_##label);                           \
    DIP_INT_OPTS_##label(_INT_STR_##label);                             \
    DIP_ENUM_OPTS_##label(_ENUM_STR_##label);


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


// When country-specific DIP definition are not provided, fallback
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
#define _ENUM_CFG(num,title,choices,selected) , [num] = {selected, _LEN(choices)}

// Time DIP description
#define _TIME_STR(country,num,title,minutes,seconds)                     \
    const char dip_##country##_time##_##num##_##name[12] _SECTION = _PAD12(title);
// Integer DIP description
#define _INT_STR(country,num,title,value)                                \
    const char dip_##country##_int##_##num##_##name[12] _SECTION = _PAD12(title);
// Enum DIP description
#define _ENUM_STR(country,num,title,choices,selected)                            \
    const char dip_##country##_enum##_##num##_##name[12] _SECTION = _PAD12(title);        \
    const char dip_##country##_enum##_##num##_##choice[][12] _SECTION = {_MAP_PAD12 choices};

/* Country-specific visitors just call the generic ones */
#define _TIME_STR_jp(num,title,minutes,seconds) _TIME_STR(jp,num,title,minutes,seconds)
#define _TIME_STR_us(num,title,minutes,seconds) _TIME_STR(us,num,title,minutes,seconds)
#define _TIME_STR_eu(num,title,minutes,seconds) _TIME_STR(eu,num,title,minutes,seconds)
#define _INT_STR_jp(num,title,value) _INT_STR(jp,num,title,value)
#define _INT_STR_us(num,title,value) _INT_STR(us,num,title,value)
#define _INT_STR_eu(num,title,value) _INT_STR(eu,num,title,value)
#define _ENUM_STR_jp(num,title,choices,selected) _ENUM_STR(jp,num,title,choices,selected)
#define _ENUM_STR_us(num,title,choices,selected) _ENUM_STR(us,num,title,choices,selected)
#define _ENUM_STR_eu(num,title,choices,selected) _ENUM_STR(eu,num,title,choices,selected)


// Disable automatic padding (for debugging purpose only)
#ifndef _DIP_NO_PADDING_

// Convert a C string to a 16-bytes, space-padded data (non null terminated)
// e.g. `foo\0` -> `foo             `
#define _PAD16(s)                                             \
    __builtin_choose_expr(sizeof(s)== 1,s"                ",  \
    __builtin_choose_expr(sizeof(s)== 2,s"               ",   \
    __builtin_choose_expr(sizeof(s)== 3,s"              ",    \
    __builtin_choose_expr(sizeof(s)== 4,s"             ",     \
    __builtin_choose_expr(sizeof(s)== 5,s"            ",      \
    __builtin_choose_expr(sizeof(s)== 6,s"           ",       \
    __builtin_choose_expr(sizeof(s)== 7,s"          ",        \
    __builtin_choose_expr(sizeof(s)== 8,s"         ",         \
    __builtin_choose_expr(sizeof(s)== 9,s"        ",          \
    __builtin_choose_expr(sizeof(s)==10,s"       ",           \
    __builtin_choose_expr(sizeof(s)==11,s"      ",            \
    __builtin_choose_expr(sizeof(s)==12,s"     ",             \
    __builtin_choose_expr(sizeof(s)==13,s"    ",              \
    __builtin_choose_expr(sizeof(s)==14,s"   ",               \
    __builtin_choose_expr(sizeof(s)==15,s"  ",                \
    __builtin_choose_expr(sizeof(s)==16,s" ",                 \
    s))))))))))))))))

// Convert a C string to a 12-bytes, space-padded data (non null terminated)
// e.g. `bar\0` -> `bar         `
#define _PAD12(s)                                         \
    __builtin_choose_expr(sizeof(s)== 1,s"            ",  \
    __builtin_choose_expr(sizeof(s)== 2,s"           ",   \
    __builtin_choose_expr(sizeof(s)== 3,s"          ",    \
    __builtin_choose_expr(sizeof(s)== 4,s"         ",     \
    __builtin_choose_expr(sizeof(s)== 5,s"        ",      \
    __builtin_choose_expr(sizeof(s)== 6,s"       ",       \
    __builtin_choose_expr(sizeof(s)== 7,s"      ",        \
    __builtin_choose_expr(sizeof(s)== 8,s"     ",         \
    __builtin_choose_expr(sizeof(s)== 9,s"    ",          \
    __builtin_choose_expr(sizeof(s)==10,s"   ",           \
    __builtin_choose_expr(sizeof(s)==11,s"  ",            \
    __builtin_choose_expr(sizeof(s)==12,s" ",             \
    s))))))))))))

// macros to iterate over an arbitrary-length array of string
// and return an array of space-padded 12-bytes strings
#define _MAP_PAD12(a,...)   _MAP_PAD12_1(__VA_ARGS__) ,[sizeof(""a)==1?0:0] = _PAD12(""a)
#define _MAP_PAD12_1(a,...) _MAP_PAD12_2(__VA_ARGS__) ,[sizeof(""a)==1?0:1] = _PAD12(""a)
#define _MAP_PAD12_2(a,...) _MAP_PAD12_3(__VA_ARGS__) ,[sizeof(""a)==1?0:2] = _PAD12(""a)
#define _MAP_PAD12_3(a,...) _MAP_PAD12_4(__VA_ARGS__) ,[sizeof(""a)==1?0:3] = _PAD12(""a)
#define _MAP_PAD12_4(a,...) _MAP_PAD12_5(__VA_ARGS__) ,[sizeof(""a)==1?0:4] = _PAD12(""a)
#define _MAP_PAD12_5(a,...) _MAP_PAD12_6(__VA_ARGS__) ,[sizeof(""a)==1?0:5] = _PAD12(""a)
#define _MAP_PAD12_6(a,...) _MAP_PAD12_7(__VA_ARGS__) ,[sizeof(""a)==1?0:6] = _PAD12(""a)
#define _MAP_PAD12_7(a,...) _MAP_PAD12_8(__VA_ARGS__) ,[sizeof(""a)==1?0:7] = _PAD12(""a)
#define _MAP_PAD12_8(a,...) _MAP_PAD12_9(__VA_ARGS__) ,[sizeof(""a)==1?0:8] = _PAD12(""a)
#define _MAP_PAD12_9(a,...) _MAP_PAD12_10(__VA_ARGS__) ,[sizeof(""a)==1?0:9] = _PAD12(""a)
#define _MAP_PAD12_10(a,...) _MAP_PAD12_11(__VA_ARGS__) ,[sizeof(""a)==1?0:10] = _PAD12(""a)
#define _MAP_PAD12_11(a,...) _MAP_PAD12_12(__VA_ARGS__) ,[sizeof(""a)==1?0:11] = _PAD12(""a)
#define _MAP_PAD12_12(a,...) _MAP_PAD12_13(__VA_ARGS__) ,[sizeof(""a)==1?0:12] = _PAD12(""a)
#define _MAP_PAD12_13(a,...) _MAP_PAD12_14(__VA_ARGS__) ,[sizeof(""a)==1?0:13] = _PAD12(""a)
#define _MAP_PAD12_14(a,...) _MAP_PAD12_15(__VA_ARGS__) ,[sizeof(""a)==1?0:14] = _PAD12(""a)
#define _MAP_PAD12_15(a,...) _MAP_PAD12_16(__VA_ARGS__) ,[sizeof(""a)==1?0:15] = _PAD12(""a)
#define _MAP_PAD12_16(n) [0]="      "

#else

#define _PAD16(s) s
#define _PAD12(s) s
#define _MAP_PAD12(...) __VA_ARGS__

#endif

// length of an arbitrary long array of string
#define _LEN(x) _LEN2 x
#define _LEN2(...) (sizeof(((char*[]){ __VA_ARGS__ }))/sizeof(char*))


#endif /* __NGDEVKIT_NG_DIP_H__ */
