/*
 * Copyright (c) 2026 Damien Ciabrini
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

#include <ngdevkit/memory-card.h>
#include <ngdevkit/registers.h>


void ng_memory_card_unlock(void) {
    // The memory card is deemed unlocked in software only after the two
    // memory-mapped unlock bits have been set.
    *REG_CRDUNLOCK1 = 1;
    *REG_CRDUNLOCK2 = 1;
}
