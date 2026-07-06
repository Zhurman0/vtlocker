#ifndef VTCTL_H
#define VTCTL_H

#include <signal.h>

extern volatile sig_atomic_t relsig_pending;
extern volatile sig_atomic_t acqsig_pending;

void vtctl_init();
int vtctl_active_vt(int tty_fd);
void vtctl_set_process(int tty_fd);
void vtctl_set_auto(int tty_fd);
void vtctl_deny_switch(int tty_fd);

#endif
