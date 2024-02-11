#pragma once

#if defined(_MSC_VER) && _MSC_VER < 1900 // VS2013 or before

#include <stdio.h>
#include <stdarg.h>

#pragma warning(push)
#pragma warning(disable: 4996) // warning _vsnprintf() is unsafe.
// Emulate C99 snprintf() with _snprintf().
static int msvc_snprintf(char *buf, size_t bufsz, const char *fmt, ...)
{
    int len;
    va_list va;
    va_start(va, fmt);
    len = _vsnprintf(buf, bufsz, fmt, va);
    va_end(va);
    if (!buf) {
        // (bufsz > 0) -> Should already crash.
        // (bufsz == 0) -> Return required buffer size.
    }
    else if (len >= 0 && (size_t)len <= bufsz) {
        if (len == bufsz && bufsz > 0)
            buf[bufsz - 1] = '\0'; // Ensure null termination.
        // len is correct required buffer size in this case.
    }
    else {
        // _vsnprintf() does not return required buffer size in case of overflow.
        // Recall _vsnprintf() in special way to find out.
        va_start(va, fmt);
        len = _vsnprintf(NULL, 0, fmt, va); // Get required buffer size.
        va_end(va);
        // assert(len == -1 || len > bufsz);
        if (bufsz > 0)
            buf[bufsz - 1] = '\0'; // Ensure null termination.
    }
    return len;
}
#pragma warning(pop)

#define snprintf msvc_snprintf

#endif // VS2013 or before
