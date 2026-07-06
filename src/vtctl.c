#include "vtctl.h"
#include <sys/ioctl.h>
#include <linux/vt.h>
#include <stdio.h>
#include <signal.h>

volatile sig_atomic_t relsig_pending = 0;
volatile sig_atomic_t acqsig_pending = 0;

static void handle_relsig(int sig)
{
    (void)sig;
    relsig_pending = 1;
}

static void handle_acqsig(int sig)
{
    (void)sig;
    acqsig_pending = 1;
}

void vtctl_init()
{
    struct sigaction sa_rel = {0}, sa_acq = {0};

    sa_rel.sa_handler = handle_relsig;
    sa_rel.sa_flags   = SA_RESTART;
    sigemptyset(&sa_rel.sa_mask);

    sa_acq.sa_handler = handle_acqsig;
    sa_acq.sa_flags   = SA_RESTART;
    sigemptyset(&sa_acq.sa_mask);

    if (sigaction(SIGUSR1, &sa_rel, NULL) < 0)
        perror("sigaction SIGUSR1");

    if (sigaction(SIGUSR2, &sa_acq, NULL) < 0)
        perror("sigaction SIGUSR2");
}

int vtctl_active_vt(int tty_fd)
{
    struct vt_stat st;
    if (ioctl(tty_fd, VT_GETSTATE, &st) < 0) {
        perror("VT_GETSTATE");
        return -1;
    }
    return st.v_active;
}

void vtctl_set_process(int tty_fd)
{
    struct vt_mode mode;

    if (ioctl(tty_fd, VT_GETMODE, &mode) < 0) {
        perror("VT_GETMODE");
        return;
    }

    mode.mode   = VT_PROCESS;
    mode.waitv  = 0;
    mode.relsig = SIGUSR1;
    mode.acqsig = SIGUSR2;
    mode.frsig  = 0;

    if (ioctl(tty_fd, VT_SETMODE, &mode) < 0)
        perror("VT_SETMODE");
}

void vtctl_set_auto(int tty_fd)
{
    struct vt_mode mode;
    if (ioctl(tty_fd, VT_GETMODE, &mode) < 0) {
        perror("VT_GETMODE");
        return;
    }

    mode.mode = VT_AUTO;

    if (ioctl(tty_fd, VT_SETMODE, &mode) < 0)
        perror("VT_SETMODE");
}

void vtctl_deny_switch(int tty_fd)
{
    if (ioctl(tty_fd, VT_RELDISP, 0) < 0)
        perror("VT_RELDISP deny");
}
