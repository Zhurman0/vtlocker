#ifndef UI_H
#define UI_H

#include <stddef.h>


enum ui_input_mode {
    UI_INPUT_LOGIN,
    UI_INPUT_PASSWORD
};



void ui_init(int tty_fd);
void ui_clear_all(void);

void ui_status(const char kind);

void ui_message(const char *msg);
void ui_error(const char *msg);

void ui_prompt_login(void);
void ui_prompt_password(void);

void ui_timer(int sec);

enum ui_input_mode ui_current_mode(void);
void ui_begin_input(enum ui_input_mode mode, char *buf, size_t maxlen);
void ui_feed_char(char ch);
int ui_input_done(void);

#endif
