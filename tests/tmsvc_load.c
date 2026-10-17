/* Copyright (C) 2026 code-agent-43824
   SPDX-License-Identifier: Apache-2.0 */

#include <openssl/err.h>
#include <openssl/provider.h>
#include <stdio.h>
#include <string.h>

static int print_error(const char *text, size_t size, void *unused)
{
    (void)unused;
    return fwrite(text, 1, size, stderr) == size;
}

int main(void)
{
    OSSL_PROVIDER *provider = OSSL_PROVIDER_load(NULL, "pkcs11");
    if (provider == NULL) {
        ERR_print_errors_cb(print_error, NULL);
        return 1;
    }
    if (strcmp(OSSL_PROVIDER_get0_name(provider), "pkcs11") != 0) {
        OSSL_PROVIDER_unload(provider);
        return 2;
    }
    return OSSL_PROVIDER_unload(provider) == 1 ? 0 : 3;
}
