/*
 * controllers management for BIOS
 * Copyright (c) 2025 Damien Ciabrini
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

#include <ngdevkit/bios-backup-ram.h>
#include <ngdevkit/registers.h>
#include "utils.h"

// Note: when gcc determines that a variable holds a constant rvalues,
// it skips register assignment and generate instructions with
// immediate addressing mode instead, which can be suboptimal.
//
// In the functions below, we use asm block to assign variables for
// which gcc must not perform constant optimizations. This yields
// better performance:
//   - peephole generates faster loops that use the "dbra" opcode
//   - the memory writes in the loop have a smaller code size

// BIOS public API

#define OPAQUE_TILE      0x20
#define TRANSPARENT_TILE 0xff

void impl_fix_clear() {
    s16 loop;
    u16 tile;

    volatile u16 *vram;
    // VRAM access: beginning of tile map, 1 byte per write (next tile down)
    *REG_VRAMADDR = ADDR_FIXMAP;
    *REG_VRAMMOD = 1;
    SET_CONST_ADDR(vram, REG_VRAMRW);

    // left column
    SET_CONST_W(loop, 32-1);
    SET_CONST_W(tile, OPAQUE_TILE);
    do { *vram = tile; } while(--loop != -1);
    // full center tilemap
    SET_CONST_W(loop, 32*38-1);
    SET_CONST_W(tile, TRANSPARENT_TILE);
    do { *vram = tile; } while(--loop != -1);
    // right column
    SET_CONST_W(loop, 32-1);
    SET_CONST_W(tile, OPAQUE_TILE);
    do { *vram = tile; } while(--loop != -1);
}


#define SCB2_VAL(zx, zy) (((zx)<<8) | (zy))
#define SCB3_VAL(y, sticky, size) ((((y))<<7) | ((sticky)<<6) | (size))
#define SCB4_VAL(x) ((x)<<7)

void impl_lsp_1st() {
    s16 loop;
    u16 val;

    volatile u16 *vram;
    // VRAM access: sprite attributes, 1 byte per write (to next sprite)
    *REG_VRAMADDR = ADDR_SCB2;
    *REG_VRAMMOD = 1;
    SET_CONST_ADDR(vram, REG_VRAMRW);

    // current VRAM pointer: SCB2
    // reset shrink coefficient: max x (0xf) | max y (0xff)
    SET_CONST_W(loop, 512-1);
    SET_CONST_W(val, SCB2_VAL(0xf, 0xff));
    do { *vram = val; } while(--loop != -1);
    // current VRAM pointer: SCB3
    // reset vertical position: topmost (0)
    SET_CONST_W(loop, 512-1);
    SET_CONST_W(val, SCB3_VAL(0, 0, 0));
    do { *vram = val; } while(--loop != -1);
    // current VRAM pointer: SCB4
    // reset horizontal position: leftmost (0)
    SET_CONST_W(loop, 512-1);
    SET_CONST_W(val, SCB4_VAL(380));
    do { *vram = val; } while(--loop != -1);
    // special case: configure all tiles of 1st sprite to be transparent
    *REG_VRAMADDR = ADDR_SCB1;
    *REG_VRAMMOD = 2;
    SET_CONST_W(loop, 32-1);
    SET_CONST_W(val, TRANSPARENT_TILE);
    do { *vram = val; } while(--loop != -1);
}
