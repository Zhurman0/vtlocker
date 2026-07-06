#include "termctl.h"
#include <unistd.h>
#include <termios.h>

static struct termios old_tio;
static int saved_fd = -1;

void termctl_init(int tty_fd)
{
    saved_fd = tty_fd;
    tcgetattr(tty_fd, &old_tio);

    struct termios tio = old_tio;

    /* raw input */
    tio.c_lflag &= ~(ICANON | ECHO | ISIG);
    tio.c_iflag &= ~(ICRNL | IXON);
    tio.c_oflag &= ~(OPOST);

    tio.c_cc[VMIN]  = 1;
    tio.c_cc[VTIME] = 0;

    tcsetattr(tty_fd, TCSANOW, &tio);
}

void termctl_restore(void)
{
    tcsetattr(saved_fd, TCSANOW, &old_tio);
}
