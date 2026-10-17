/* Copyright (C) 2026 code-agent-43824
   SPDX-License-Identifier: Apache-2.0 */

#include <stddef.h>
#include "pkcs11.h"

_Static_assert(sizeof(CK_ULONG) == 4, "Windows CK_ULONG must be 32-bit");
_Static_assert(offsetof(CK_FUNCTION_LIST, C_Initialize) == 2,
               "CK_FUNCTION_LIST must not pad after CK_VERSION");
_Static_assert(offsetof(CK_FUNCTION_LIST_3_0, C_Initialize) == 2,
               "CK_FUNCTION_LIST_3_0 must not pad after CK_VERSION");
_Static_assert(offsetof(CK_FUNCTION_LIST_3_2, C_Initialize) == 2,
               "CK_FUNCTION_LIST_3_2 must not pad after CK_VERSION");
_Static_assert(offsetof(CK_ATTRIBUTE, pValue) == 4,
               "CK_ATTRIBUTE must not pad before pValue");
_Static_assert(offsetof(CK_ATTRIBUTE, ulValueLen) == 4 + sizeof(void *),
               "CK_ATTRIBUTE must not pad before ulValueLen");
_Static_assert(sizeof(CK_ATTRIBUTE) == 8 + sizeof(void *),
               "CK_ATTRIBUTE must not have tail padding");
_Static_assert(offsetof(CK_MECHANISM, pParameter) == 4,
               "CK_MECHANISM must not pad before pParameter");
_Static_assert(offsetof(CK_C_INITIALIZE_ARGS, pReserved) ==
                   4 * sizeof(void *) + sizeof(CK_FLAGS),
               "CK_C_INITIALIZE_ARGS must not pad before pReserved");

struct pack_restore_check {
    char first;
    void *second;
};

_Static_assert(offsetof(struct pack_restore_check, second) == sizeof(void *),
               "pkcs11.h must restore the previous packing");

int main(void)
{
    return 0;
}
