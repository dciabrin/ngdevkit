/*
 * Syscall implementation as expected by newlib
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

#include <_ansi.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <stdio.h>
#include <time.h>
#include <sys/time.h>
#include <sys/times.h>
#include <errno.h>
#include <reent.h>

/* _end is defined by the link script, it is the base of allocatable space */
extern char _end[];


int read (int file, char * ptr, int len) {
  errno = EBADF;
  return -1;
}

int lseek (int file, int ptr, int dir) {
  errno = EBADF;
  return -1;
}

int write (int file, char * ptr, int len) {
  errno = EBADF;
  return -1;
}

int open (const char * path, int flags, ... ) {
  errno = EMFILE;
  return -1;
}

int close (int file) {
  errno = EBADF;
  return -1;
}

void exit (int n) { 
  for(;;);
}

int kill (int n, int m) {
  errno = EINVAL;
  return -1;
}

int getpid (int n) {
  return 1;
}

caddr_t sbrk (int nbytes) {
  static char *heap;
  char *sp;

  if (!heap)
    heap = (char *)&_end;

  __asm__ __volatile__ ("move.l %%sp, %0" : "=r" (sp) );
  if ((sp - heap - nbytes) >= 0) {
    char *old = heap;
    heap += nbytes;
    return (old);
  } else {
    errno = ENOMEM;
    return ((char *)-1);
  }
}

int fstat (int file, struct stat * st) {
  errno = EBADF;
  return -1;
}

int link (void) {
  errno = ENOENT;
  return -1;
}

int unlink (void) {
  errno = ENOENT;
  return -1;
}

void raise (void) {
  return;
}

int gettimeofday (struct timeval * tp, struct timezone * tzp) {
  errno = EINVAL;
  return -1;
}

clock_t times (struct tms * tp) {
  errno = EINVAL;
  return (clock_t) -1;
}

int isatty (int fd) {
  return 0;
}
