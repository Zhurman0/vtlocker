#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sys/epoll.h>

#include "termctl.h"
#include "pamctl.h"
#include "vtctl.h"
#include "ui.h"


int main(void)
{
    int tty_fd = open("/dev/tty", O_RDWR | O_NONBLOCK);
    if (tty_fd < 0) {
        perror("open /dev/tty");
        return 1;
    }

    int ep = epoll_create1(0);
    struct epoll_event ev = {
        .events = EPOLLIN,
        .data.fd = tty_fd
    };
    epoll_ctl(ep, EPOLL_CTL_ADD, tty_fd, &ev);


    int my_vt = vtctl_active_vt(tty_fd);

    termctl_init(tty_fd);
    vtctl_init();

    vtctl_set_process(tty_fd);

    ui_init(tty_fd);
    ui_status(1);
    ui_message("");

    char username[64], password[64];

    while (1) {
        ui_begin_input(UI_INPUT_LOGIN, username, sizeof(username));

        while (1) {
            struct epoll_event events[4];
            int n = epoll_wait(ep, events, 4, 100);

            if (relsig_pending) {
                relsig_pending = 0;
                vtctl_deny_switch(tty_fd);
                ui_error("VT switch denied");
            }

            if (acqsig_pending) {
                acqsig_pending = 0;
                ui_message("ACQ signal");
            }
            

            if (n > 0) {
                for (int i = 0; i < n; i++) {
                    if (events[i].data.fd == tty_fd) {
                        char ch;
                        if (read(tty_fd, &ch, 1) > 0)
                            ui_feed_char(ch);
                    }
                }
            }

            if (ui_input_done() && ui_current_mode() == UI_INPUT_LOGIN) {
                ui_begin_input(UI_INPUT_PASSWORD, password, sizeof(password));
                continue;
            }

            if (ui_input_done() && ui_current_mode() == UI_INPUT_PASSWORD)
                break;
        }

        if (pamctl_auth(username, password)) {
            ui_message("Authentication OK");
            break;
        } else {
            ui_error("Authentication failed");
        }
    }
    

    ui_status(0);
    vtctl_set_auto(tty_fd);
    termctl_restore();


    for (int sec = 10; sec >= 0; sec--) {
        ui_timer(sec);

        int cur = vtctl_active_vt(tty_fd);
        if (cur != my_vt) break;

        sleep(1);
    }


    close(tty_fd);

    return 0;
}
