/* 
 * Copyright (c) 2015 Damien Ciabrini
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

#include <ng/neogeo.h>

/// Start of character tiles in BIOS ROM
#define SROM_TXT_TILE_OFFSET 0

/// Transparent tile in BIOS ROM
#define SROM_EMPTY_TILE 255

/// Handy function to display a string on the fix map
void display(int x, int y, const char *text) {
  *REG_VRAMADDR=ADDR_FIXMAP+(x<<5)+y;
  *REG_VRAMMOD=32;
  while (*text) *REG_VRAMRW=(u16)(SROM_TXT_TILE_OFFSET+*text++);
}


int main(void) {
  // Clear the 40*32 tiles of fix map
  *REG_VRAMADDR=ADDR_FIXMAP;
  *REG_VRAMMOD=1;
  for (u16 i=0;i<1280;i++) {
    *REG_VRAMRW=(u16)SROM_EMPTY_TILE;
  }

  // Set up a minimal palette
  const u16 palette[]={0x8000, 0xfff};
  for (u16 i=0; i<3; i++) {
    MMAP_PALBANK1[i]=palette[i];
  }

  // Salute the world!
  const char hello1[]="hello NEO-GEO!";
  const char hello2[]="http://github.com/dciabrin/ngdevkit";
  display((40-sizeof(hello1))/2, 10, hello1);
  display((40-sizeof(hello2))/2, 12, hello2);

  for(;;) {}
  return 0;
}
