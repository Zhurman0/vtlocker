#include "ui.h"
#include <sys/ioctl.h>
#include <stdio.h>
#include <string.h>

#define CSI "\x1b["


static int tty_fd_global;
static int status_row, msg_row, login_row, pass_row;

static int err_count = 0;
static char last_err[128];

static enum ui_input_mode input_mode;
static char *input_buf;
static size_t input_max;
static size_t input_pos;
static int input_col;
static int input_done_flag = 0;


static void ui_move(int r, int c)
{
    printf(CSI "%d;%dH", r, c);
}

static void ui_center_input(int row, const char *text, const char delta)
{
    struct winsize ws;
    ioctl(tty_fd_global, TIOCGWINSZ, &ws);

    int len = strlen(text);
    int col = (ws.ws_col - len) / 2 - delta;
    if (col < 1) col = 1;

    ui_move(row, col);
    fputs(text, stdout);

    input_col = col + len;

    fflush(stdout);
}

static void ui_center_text(int row, const char *text)
{
    struct winsize ws;
    ioctl(tty_fd_global, TIOCGWINSZ, &ws);

    int len = strlen(text);
    int col = (ws.ws_col - len) / 2;
    if (col < 1) col = 1;

    ui_move(row, col);
    fputs(text, stdout);

    fflush(stdout);
}


static void ui_clear_line(int row)
{
    printf("\033[%d;1H", row);
    printf("\033[2K\033[G");
}


void ui_clear_all(void)
{
    fputs(CSI "2J" CSI "H", stdout);
}


void ui_init(int tty_fd)
{
    tty_fd_global = tty_fd;

    struct winsize ws;
    ioctl(tty_fd, TIOCGWINSZ, &ws);

    int center = ws.ws_row / 2;

    status_row = center - 2;
    msg_row    = center - 1;
    login_row  = center + 1;
    pass_row   = center + 2;;

    ui_clear_all();
}

void ui_status(const char kind)
{
    ui_center_text(status_row, kind == 1 ? "Status: LOCKED" : "Status: UNLOCKED");
}

void ui_message(const char *msg)
{
    ui_clear_line(msg_row);
    ui_center_text(msg_row, msg);
    ui_move((input_mode == UI_INPUT_LOGIN ? login_row : pass_row), input_col + input_pos);
}

void ui_error(const char *msg)
{   
    if (err_count == 0) {
        strncpy(last_err, msg, sizeof(last_err)-1);
        err_count = 1;
    } else if (strcmp(last_err, msg) == 0) {
        err_count++;
    } else {
        strncpy(last_err, msg, sizeof(last_err)-1);
        err_count = 1;
    }

    char buf[128];
    if (err_count > 1)
        snprintf(buf, sizeof(buf), "%s (x%d)", last_err, err_count);
    else
        snprintf(buf, sizeof(buf), "%s", last_err);

    ui_message(buf);
}


void ui_prompt_login(void)
{
    ui_clear_line(login_row);
    ui_center_input(login_row, "Login: ", 3);
}

void ui_prompt_password(void)
{
    ui_clear_line(pass_row);
    ui_center_input(pass_row, "Password: ", 5);
}

void ui_timer(int sec)
{
    ui_clear_line(login_row);
    ui_clear_line(pass_row);
    
    char buf[64];
    snprintf(buf, sizeof(buf), "Exiting in %d s", sec);
    ui_center_text(login_row, buf);
}


enum ui_input_mode ui_current_mode(void)
{
    return input_mode;
}

void ui_begin_input(enum ui_input_mode mode, char *buf, size_t maxlen)
{
    input_mode = mode;
    input_buf  = buf;
    input_max  = maxlen;
    input_pos  = 0;
    input_done_flag = 0;

    if (mode == UI_INPUT_LOGIN) {
        ui_prompt_login();
    } else {
        ui_prompt_password();
    }
}

void ui_feed_char(char ch)
{
    int row = (input_mode == UI_INPUT_LOGIN ? login_row : pass_row);

    switch (ch) {
        case '\r': case '\n':
            input_buf[input_pos] = 0;
            input_done_flag = 1;
            return;

        case 127: case '\b':
            if (input_pos > 0) {
                input_pos--;

                int col = input_col + input_pos;

                ui_move(row, col);
                putchar(' ');
                ui_move(row, col);

                fflush(stdout);
            }
            return;

        default:
            if (input_pos >= input_max - 1) return

            ui_move(row, input_col + input_pos);
            putchar(input_mode == UI_INPUT_PASSWORD ? '*' : ch);

            input_buf[input_pos++] = ch;

            fflush(stdout);
            return;
    }
}

int ui_input_done(void)
{
    return input_done_flag;
}
