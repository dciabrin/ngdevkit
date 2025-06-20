/*
 * Copyright (c) 2015-2025 Damien Ciabrini
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

#ifndef __NGDEVKIT_NG_FIX_H__
#define __NGDEVKIT_NG_FIX_H__

#ifdef __cplusplus
extern "C" {
#endif

/// Start of character tiles in GAME ROM
#ifndef SROM_TXT_TILE_OFFSET
#define SROM_TXT_TILE_OFFSET 0
#endif

/// Start of tall character tiles in GAME ROM
#ifndef SROM_TXT_TALL_TILE_OFFSET
#define SROM_TXT_TALL_TILE_OFFSET 256
#endif

/// Transparent tile in GAME ROM
#ifndef SROM_EMPTY_TILE
#define SROM_EMPTY_TILE 255
#endif


/// Clear the 40*32 tiles of fix map
extern void ng_cls_args(u8 palette, u16 tile);

/// Display a string on the fix map
extern void ng_text_args(u8 x, u8 y, u8 palette, u16 start_tile, const char *text);

/// Display a tall string on the fix map
extern void ng_text_tall_args(u8 x, u8 y, u8 palette, u16 start_tile, const char *text);

/// Display a centered string on the fix map
extern void ng_center_text_args(u8 y, u8 palette, u16 start_tile, const char *text);

/// Display a centeredtall string on the fix map
extern void ng_center_text_tall_args(u8 y, u8 palette, u16 start_tile, const char *text);


#define ng_text(x,y,pal,text) \
    ng_text_args((x), (y), (pal), SROM_TXT_TILE_OFFSET, (text))

#define ng_text_tall(x,y,pal,text) \
    ng_text_tall_args((x), (y), (pal), SROM_TXT_TALL_TILE_OFFSET, (text))

#define ng_center_text(y,pal,text) \
    ng_center_text_args((y), (pal), SROM_TXT_TILE_OFFSET, (text))

#define ng_center_text_tall(y,pal,text)                               \
    ng_center_text_tall_args((y), (pal), SROM_TXT_TALL_TILE_OFFSET, (text))

#define ng_cls() ng_cls_args(0, SROM_EMPTY_TILE)

#ifdef __cplusplus
}
#endif

#endif /* __NGDEVKIT_NG_FIX_H__ */
