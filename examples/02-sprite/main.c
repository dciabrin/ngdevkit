/*
 * Copyright (c) 2018 Damien Ciabrini
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

// Additional resources for sprites
// https://wiki.neogeodev.org/index.php?title=Sprites

#include <ng/neogeo.h>
#include <stdio.h>

/// for snprintf()
int __errno;

// Address of Sprite Control Block in VRAM
#define ADDR_SCB1      0
#define ADDR_SCB2 0x8000
#define ADDR_SCB3 0x8200

/// Start of character tiles in BIOS ROM
#define SROM_TXT_TILE_OFFSET 0

/// Transparent tile in BIOS ROM
#define SROM_EMPTY_TILE 255

/// First tile for the sprite in the ROM
#define START_TILE 60


/// Handy function to display a string on the fix map
void display(int x, int y, const char *text) {
  *REG_VRAMADDR=ADDR_FIXMAP+(x<<5)+y;
  *REG_VRAMMOD=32;
  while (*text) *REG_VRAMRW=(u16)(SROM_TXT_TILE_OFFSET+*text++);
}

// Clear the 40*32 tiles of fix map
void clear_tiles() {
    *REG_VRAMADDR=ADDR_FIXMAP;
    *REG_VRAMMOD=1;
    for (u16 i=0;i<40*32;i++) {
        *REG_VRAMRW=(u16)SROM_EMPTY_TILE;
    }
}

void init_palette() {
    /// first 16 colors palette for the fix tiles
    /// second 16 colors palette for the sprite
    const u16 clut[]= { 0x0000, 0x0fa0, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
                        0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
                        0x0000, 0x0fff, 0x0ddd, 0x0aaa, 0x7555, 0x306E, 0x0000, 0x0000,
                        0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 };

    /// Initialize the two palettes in the first palette bank
    for (u16 i=0;i<32; i++) {
        MMAP_PALBANK1[i]=clut[i];
    }
}

/* void display(int x, int y, const char *text) { */
/*     *REG_VRAMADDR=ADDR_FIXMAP+(x<<5)+y; */
/*     *REG_VRAMMOD=32; */
/*     while (*text) *REG_VRAMRW=(u16)*text++; */
/* } */


s16 x=40;
s16 y=-80;

// Sprite setup.
//
// The sprite is 15 tiles long x 4 tiles tall
// For the Neo Geo hardware, it's a series of
// 15 concatenated vertical sprites of 4 tiles
void init_sprite() {
    // Every write to the VRAM will increment the
    // VRAM address pointer by 1 byte.
    *REG_VRAMMOD=1;

    // Set the tile information (tile number, color, mirror)
    // in the Sprite Control Block 1 (SCB1)
    for (u8 i=0; i<15; i++) {
         // address of the i-th sprite in SCB1
        *REG_VRAMADDR=ADDR_SCB1+(i*64); // i-th sprite in SCB1

        u16 tile = START_TILE + i;      // i-th tile in c-ROM
        u16 attr = 1<<8;                // palette 1, no mirrorring
        *REG_VRAMRW=tile;
        *REG_VRAMRW=attr;

        // the next write in VRAM targets the subsequent vertical
        // tiles for this i-th sprite.
        *REG_VRAMRW=tile+15;            // next vertical tile
        *REG_VRAMRW=attr;               // palette 1, no mirroring
        *REG_VRAMRW=tile+30;            // ...
        *REG_VRAMRW=attr;
        *REG_VRAMRW=tile+45;
        *REG_VRAMRW=attr;
    }

    // Sprite zoom, size and position are specified in Sprite Control
    // Block 2, 3 and 4.
    // The first vertical sprite controls the overall location and zoom,
    // the other 15 vertical sprites are just defined as 'sticky', i.e.
    // they follow the location of their previous sibling.

    // SCB2, SCB3 and SCB4 are 0x200 bytes away from each other
    *REG_VRAMMOD=0x200;

    // Vertical sprite 0
    *REG_VRAMADDR=ADDR_SCB2;
    // SCB2: max zoom
    *REG_VRAMRW=0xFFF;
    // SCB3: y position, not sticky, 4 tiles tall
    *REG_VRAMRW=(y<<7)+4;
    // SCB4: x position
    *REG_VRAMRW=(x<<7);

    // the remaining 14 vertical sprites are sticky
    for (u16 i=1; i<15; i++) {
        *REG_VRAMADDR=ADDR_SCB2+i;      // i-th sprite
        *REG_VRAMRW=0xFFF;              // max zoom
        *REG_VRAMRW=1<<6;;              // sticky
    }
}


char joystate[5]={'0','0','0','0',0};

// Get joystick status and move sprite position
void check_move_sprite()
{
    u8 js1=*REG_P1CNT^0xff;
    u8 u=(js1>>0 & 1);
    u8 d=(js1>>1 & 1);
    u8 l=(js1>>2 & 1);
    u8 r=(js1>>3 & 1);

    joystate[0]='0'+u;
    joystate[1]='0'+d;
    joystate[2]='0'+l;
    joystate[3]='0'+r;

    if (u) {y+=1;}
    if (d) {y-=1;}
    if (l) {x-=1;}
    if (r) {x+=1;}

    // Update sprite position
    *REG_VRAMMOD=0x200;
    *REG_VRAMADDR=ADDR_SCB3;
    *REG_VRAMRW=(y<<7)+4;
    *REG_VRAMRW=(x<<7);
}


// Vertical blanking.
volatile u8 vblank=0;

// At each screen refresh (1/60s in NTSC), a Vertical Blank
// Interrupt is generated by the Neo Geo, and the C runtime
// automatically calls back this function below.
void rom_callback_VBlank() {
    vblank=1;
}

// Active wait until we see a screen refresh
void wait_vblank() {
    while (!vblank);
    vblank=0;
}


int main(void) {
    clear_tiles();
    init_palette();
    init_sprite();

    const char hello[]="Move the sprite with the joystick!";
    display((40-sizeof(hello))/2, 18, hello);

    char str[10];
    u8 x = 0;

    for(;;) {
        snprintf(str, 10, "frame %2d", x);
        display(15, 20, str);
        x=(x+1)%60;

        check_move_sprite();
        snprintf(str, 15, "JS1 %s", joystate);
        display(15, 21, str);

        wait_vblank();
    }
    return 0;
}
