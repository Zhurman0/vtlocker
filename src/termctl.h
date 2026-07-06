#ifndef TERMCTL_H
#define TERMCTL_H

#include <termios.h>

void termctl_init(int tty_fd);
void termctl_restore(void);

#endif
