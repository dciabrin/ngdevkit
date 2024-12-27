/*
 * Helper to wait for vblank interrupt
 * Copyright (c) 2020 Damien Ciabrini
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

#include <ngdevkit/types.h>
#include <ngdevkit/ng-video.h>


static volatile u8 vblank = 0;


// This function is called by the BIOS on each vertical blank
void rom_callback_VBlank() {
    vblank = 1;
}

void ng_wait_vblank() {
    while (!vblank);
    vblank = 0;
}
