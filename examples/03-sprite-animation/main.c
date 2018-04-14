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
char str[16];

// Address of Sprite Control Block in VRAM
#define ADDR_SCB1      0
#define ADDR_SCB2 0x8000
#define ADDR_SCB3 0x8200

/// Transparent tile in BIOS ROM
#define SROM_EMPTY_TILE 255

/// Start of character tiles in BIOS ROM
#define SROM_TXT_TILE_OFFSET 0


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

const u16 clut[][16]= {
    /// first 16 colors palette for the fix tiles
    {0x0000, 0x0fa0, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
     0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000},
    // inline sprite's palette (C format)
    #include "sprite.pal"
};

void init_palette() {
    /// Initialize the two palettes in the first palette bank
    u16 *p=(u16*)clut;
    for (u16 i=0;i<32; i++) {
        MMAP_PALBANK1[i]=p[i];
    }
    *((volatile u16*)0x401ffe)=0xa80;
}

s16 x=130;
s16 y=-80;

// Sprite setup.
//
// The example sprite is 4 x 4 tiles
// The animation uses 8 different frames/sprites
void update_sprite(u16 start_tile, u16 mirror) {
    static const u8 right_tiles[]={0,1,2,3};
    static const u8 left_tiles[]={3,2,1,0};
    const u8 *tiles = mirror?left_tiles:right_tiles;
    *REG_VRAMMOD=1;
    for (u8 i=0; i<4; i++) {
        *REG_VRAMADDR=ADDR_SCB1+(i*64); // i-th sprite in SCB1
        u16 tile = start_tile + tiles[i];
        u16 attr = (1<<8) | mirror;
        *REG_VRAMRW=tile;
        *REG_VRAMRW=attr;
        *REG_VRAMRW=tile+4;
        *REG_VRAMRW=attr;
        *REG_VRAMRW=tile+8;
        *REG_VRAMRW=attr;
        *REG_VRAMRW=tile+12;
        *REG_VRAMRW=attr;
    }

    *REG_VRAMMOD=0x200;
    // sprite shape: position , max zoon, 4 tiles tall
    *REG_VRAMADDR=ADDR_SCB2;
    *REG_VRAMRW=0xFFF;
    *REG_VRAMRW=(y<<7)+4;
    *REG_VRAMRW=(x<<7);
    for (u16 i=1; i<4; i++) {
        *REG_VRAMADDR=ADDR_SCB2+i;
        *REG_VRAMRW=0xFFF;
        *REG_VRAMRW=1<<6;
    }
}


// Get joystick status and move sprite position
void check_move_sprite()
{
    static char joystate[5]={'0','0','0','0',0};

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

    snprintf(str, 15, "JS1 %s", joystate);
    display(2, 25, str);
}


static u8 frame_cycle;
static u8 vbl=4;

void set_player_state()
{
    // tile positions in cROM for the animations
    // each frame is made of 16 tiles
    static const u16 idle_frame[8] = {60, 76, 92, 108, 124, 140, 156, 172};
    static const u16 walk_frame[8] = {188, 204, 220, 236, 252, 268, 284, 300};
    if (vbl-- == 0) {
        frame_cycle = (frame_cycle+1) & 7;
        vbl = 4;
    }

    u8 js1 = *REG_P1CNT^0xff;
    u8 l = (js1>>2 & 1);
    u8 r = (js1>>3 & 1);

    static u8 mirror;
    const u16* frame;
    if (!l && !r) {
        frame = idle_frame;
    } else {
        frame = walk_frame;
        mirror = l;
    }
    update_sprite(frame[frame_cycle], mirror);

    snprintf(str, 15, "frame  %d", frame_cycle);
    display(2, 26, str);
    snprintf(str, 15, "mirror %d", mirror);
    display(2, 27, str);
    snprintf(str, 15, "sprite %s", frame == idle_frame?"idle":"walk");
    display(2, 28, str);
}


// Vertical blanking.
volatile u8 vblank=0;

void rom_callback_VBlank() {
    vblank=1;
}

void wait_vblank() {
    while (!vblank);
    vblank=0;
}


int main(void) {
    clear_tiles();
    init_palette();

    const char hello[]="Move the sprite with the joystick!";
    display((40-sizeof(hello))/2, 18, hello);

    for(;;) {
        set_player_state();
        check_move_sprite();
        wait_vblank();
    }
    return 0;
}
