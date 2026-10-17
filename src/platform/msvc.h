/* Copyright (C) 2026 code-agent-43824
   SPDX-License-Identifier: Apache-2.0 */

#ifndef P11PROV_PLATFORM_MSVC_H
#define P11PROV_PLATFORM_MSVC_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <BaseTsd.h>
#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <time.h>

#ifdef interface
#undef interface
#endif

typedef SSIZE_T ssize_t;

/* OpenSSL's C code uses these GCC builtins for 32-bit reference counts. */
#define __ATOMIC_SEQ_CST 5
#define __atomic_fetch_add(ptr, val, order) \
    InterlockedExchangeAdd((volatile LONG *)(ptr), (LONG)(val))
#define __atomic_sub_fetch(ptr, val, order) \
    (InterlockedExchangeAdd((volatile LONG *)(ptr), -(LONG)(val)) - (LONG)(val))
#define __atomic_load_n(ptr, order) \
    InterlockedCompareExchange((volatile LONG *)(ptr), 0, 0)
#define __atomic_exchange(ptr, val, old, order) \
    (*(old) = InterlockedExchange((volatile LONG *)(ptr), *(val)))
#define __builtin_offsetof(type, member) offsetof(type, member)

typedef SRWLOCK pthread_mutex_t;

static inline int pthread_mutex_init(pthread_mutex_t *lock, const void *attr)
{
    (void)attr;
    InitializeSRWLock(lock);
    return 0;
}

static inline int pthread_mutex_lock(pthread_mutex_t *lock)
{
    AcquireSRWLockExclusive(lock);
    return 0;
}

static inline int pthread_mutex_unlock(pthread_mutex_t *lock)
{
    ReleaseSRWLockExclusive(lock);
    return 0;
}

static inline int pthread_mutex_destroy(pthread_mutex_t *lock)
{
    (void)lock;
    return 0;
}

/* A condition variable keeps read locks concurrent and writers exclusive. */
typedef struct {
    SRWLOCK state_lock;
    CONDITION_VARIABLE can_read;
    CONDITION_VARIABLE can_write;
    unsigned int readers;
    unsigned int waiting_writers;
    DWORD writer;
} pthread_rwlock_t;

#define PTHREAD_RWLOCK_INITIALIZER \
    { SRWLOCK_INIT, CONDITION_VARIABLE_INIT, CONDITION_VARIABLE_INIT, 0, 0, 0 }

static inline int pthread_rwlock_init(pthread_rwlock_t *lock, const void *attr)
{
    (void)attr;
    InitializeSRWLock(&lock->state_lock);
    InitializeConditionVariable(&lock->can_read);
    InitializeConditionVariable(&lock->can_write);
    lock->readers = 0;
    lock->waiting_writers = 0;
    lock->writer = 0;
    return 0;
}

static inline int pthread_rwlock_rdlock(pthread_rwlock_t *lock)
{
    AcquireSRWLockExclusive(&lock->state_lock);
    while (lock->writer != 0) {
        SleepConditionVariableSRW(&lock->can_read, &lock->state_lock,
                                  INFINITE, 0);
    }
    lock->readers++;
    ReleaseSRWLockExclusive(&lock->state_lock);
    return 0;
}

static inline int pthread_rwlock_wrlock(pthread_rwlock_t *lock)
{
    AcquireSRWLockExclusive(&lock->state_lock);
    lock->waiting_writers++;
    while (lock->writer != 0 || lock->readers != 0) {
        SleepConditionVariableSRW(&lock->can_write, &lock->state_lock,
                                  INFINITE, 0);
    }
    lock->waiting_writers--;
    lock->writer = GetCurrentThreadId();
    ReleaseSRWLockExclusive(&lock->state_lock);
    return 0;
}

static inline int pthread_rwlock_trywrlock(pthread_rwlock_t *lock)
{
    int ret = 0;
    AcquireSRWLockExclusive(&lock->state_lock);
    if (lock->writer != 0 || lock->readers != 0) {
        ret = EBUSY;
    } else {
        lock->writer = GetCurrentThreadId();
    }
    ReleaseSRWLockExclusive(&lock->state_lock);
    return ret;
}

static inline int pthread_rwlock_unlock(pthread_rwlock_t *lock)
{
    AcquireSRWLockExclusive(&lock->state_lock);
    if (lock->writer == GetCurrentThreadId()) {
        lock->writer = 0;
    } else if (lock->readers != 0) {
        lock->readers--;
    } else {
        ReleaseSRWLockExclusive(&lock->state_lock);
        return EPERM;
    }
    if (lock->readers == 0 && lock->waiting_writers != 0) {
        WakeConditionVariable(&lock->can_write);
    } else if (lock->writer == 0) {
        WakeAllConditionVariable(&lock->can_read);
    }
    ReleaseSRWLockExclusive(&lock->state_lock);
    return 0;
}

static inline int pthread_rwlock_destroy(pthread_rwlock_t *lock)
{
    (void)lock;
    return 0;
}

#define CLOCK_REALTIME 0
#define CLOCK_MONOTONIC 1

static inline int clock_gettime(int which, struct timespec *ts)
{
    LARGE_INTEGER now, frequency;
    if (which == CLOCK_REALTIME) {
        return timespec_get(ts, TIME_UTC) == TIME_UTC ? 0 : -1;
    }
    if (which != CLOCK_MONOTONIC || !QueryPerformanceFrequency(&frequency)
        || !QueryPerformanceCounter(&now)) {
        return -1;
    }
    ts->tv_sec = (time_t)(now.QuadPart / frequency.QuadPart);
    ts->tv_nsec = (long)((now.QuadPart % frequency.QuadPart) * 1000000000
                         / frequency.QuadPart);
    return 0;
}

static inline int nanosleep(const struct timespec *duration,
                            struct timespec *remaining)
{
    uint64_t millis = (uint64_t)duration->tv_sec * 1000
                      + ((uint64_t)duration->tv_nsec + 999999) / 1000000;
    (void)remaining;
    Sleep((DWORD)(millis > UINT32_MAX - 1 ? UINT32_MAX - 1 : millis));
    return 0;
}

static inline struct tm *localtime_r(const time_t *value, struct tm *out)
{
    return localtime_s(out, value) == 0 ? out : NULL;
}

#endif /* P11PROV_PLATFORM_MSVC_H */
