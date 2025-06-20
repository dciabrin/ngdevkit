/*
 * Bootstrap for Neo-Geo - epilogue for global init/fini section
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

        /* NOTE: these replicate libgcc's definition */

	.section .init
	unlk %fp
	rts

	.section .fini
	unlk %fp
	rts
