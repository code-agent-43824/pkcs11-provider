/* Copyright (C) 2026 code-agent-43824
   SPDX-License-Identifier: Apache-2.0 */

#include "provider.h"
#include <stdio.h>

int main(void)
{
    struct {
        CK_FLAGS flags;
        CK_RV expected;
    } cases[] = {
        { 0, CKR_OK },
        { CKF_USER_PIN_TO_BE_CHANGED, CKR_OK },
        { CKF_SO_PIN_TO_BE_CHANGED, CKR_OK },
        { CKF_USER_PIN_COUNT_LOW, CKR_OK },
        { CKF_USER_PIN_FINAL_TRY, CKR_OK },
        { CKF_USER_PIN_LOCKED, CKR_PIN_LOCKED },
        { CKF_USER_PIN_TO_BE_CHANGED | CKF_USER_PIN_FINAL_TRY, CKR_OK },
        { CKF_USER_PIN_TO_BE_CHANGED | CKF_USER_PIN_LOCKED, CKR_PIN_LOCKED },
        { CKF_USER_PIN_FINAL_TRY | CKF_USER_PIN_LOCKED, CKR_PIN_LOCKED },
    };

    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
        CK_RV actual = p11prov_check_user_pin_flags(cases[i].flags);
        if (actual != cases[i].expected) {
            fprintf(stderr, "flags=0x%lx: expected 0x%lx, got 0x%lx\n",
                    cases[i].flags, cases[i].expected, actual);
            return 1;
        }
    }

    return 0;
}
