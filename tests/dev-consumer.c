/* Verify that a project linked with OpenSSL can load the packaged provider. */
#include <openssl/err.h>
#include <openssl/provider.h>

#include "pkcs11.h"
#include <stdio.h>

#if CRYPTOKI_VERSION_MAJOR < 3
#error The packaged PKCS#11 header is older than version 3
#endif

int main(void)
{
    OSSL_PROVIDER *provider = OSSL_PROVIDER_load(NULL, "pkcs11");
    if (provider == NULL) {
        ERR_print_errors_fp(stderr);
        return 1;
    }
    OSSL_PROVIDER_unload(provider);
    return 0;
}
