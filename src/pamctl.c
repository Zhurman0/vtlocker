#include "pamctl.h"
#include <security/pam_appl.h>
#include <stdlib.h>
#include <string.h>

static int pam_conv_func(int num_msg,
                         const struct pam_message **msg,
                         struct pam_response **resp,
                         void *appdata_ptr)
{
    struct pam_response *reply = calloc(num_msg, sizeof(struct pam_response));
    if (!reply) return PAM_CONV_ERR;

    const char *password = appdata_ptr;

    for (int i = 0; i < num_msg; i++) {
        switch (msg[i]->msg_style) {
        case PAM_PROMPT_ECHO_OFF:
        case PAM_PROMPT_ECHO_ON:
            reply[i].resp = strdup(password);
            break;
        case PAM_ERROR_MSG:
        case PAM_TEXT_INFO:
            reply[i].resp = NULL;
            break;
        default:
            free(reply);
            return PAM_CONV_ERR;
        }
    }

    *resp = reply;
    return PAM_SUCCESS;
}

int pamctl_auth(const char *user, const char *pass)
{
    struct pam_conv conv = {
        .conv = pam_conv_func,
        .appdata_ptr = (void *)pass
    };

    pam_handle_t *pamh = NULL;

    int ret = pam_start("login", user, &conv, &pamh);
    if (ret != PAM_SUCCESS) return 0;

    ret = pam_authenticate(pamh, 0);
    if (ret != PAM_SUCCESS) {
        pam_end(pamh, ret);
        return 0;
    }

    ret = pam_acct_mgmt(pamh, 0);
    pam_end(pamh, ret);

    return (ret == PAM_SUCCESS);
}
