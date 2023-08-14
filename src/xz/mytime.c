///////////////////////////////////////////////////////////////////////////////
//
/// \file       mytime.c
/// \brief      Time handling functions
//
//  Author:     Lasse Collin
//
//  This file has been put into the public domain.
//  You can do whatever you want with this file.
//
///////////////////////////////////////////////////////////////////////////////

#include "private.h"

#if (defined(HAVE_CLOCK_GETTIME) && defined(HAVE_CLOCK_MONOTONIC)) || defined(_WIN32)
#	include <time.h>
#else
#	include <sys/time.h>
#endif

uint64_t opt_flush_timeout = 0;

static uint64_t start_time;
static uint64_t next_flush;


#ifdef _WIN32

#define FILETIME_N_100NS_SINCE_16010101 (116444736000000000ULL)

#if defined(_WIN32_WINNT_WIN8) && _WIN32_WINNT >= _WIN32_WINNT_WIN8
// Already targeting Windows 8 or later, no need to dynamically find the API.
#define win_GetSystemTimePreciseAsFileTime(lpSystemTimeAsFileTime) \
	(GetSystemTimePreciseAsFileTime(lpSystemTimeAsFileTime), true)
#else
static bool
win_GetSystemTimePreciseAsFileTime(LPFILETIME lpSystemTimeAsFileTime)
{
	static long __initlock = 0;
	static int volatile __inited = -1;
	typedef VOID (WINAPI *PFN_GetSystemTimePreciseAsFileTime)(LPFILETIME lpSystemTimeAsFileTime);
	static PFN_GetSystemTimePreciseAsFileTime pfn_GetSystemTimePreciseAsFileTime = NULL;

	if (InterlockedBitTestAndSet(&__initlock, 0) == 0)
	{
		HMODULE hKernel32 = NULL;
		if (GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
				      (LPCTSTR)(GetModuleHandle) /* Intentionally using function pointer */,
				      &hKernel32))
			pfn_GetSystemTimePreciseAsFileTime = (PFN_GetSystemTimePreciseAsFileTime)
				GetProcAddress(hKernel32, "GetSystemTimePreciseAsFileTime");
		__inited = 1;
	}
	else
	{
		while (__inited < 0) Sleep(0);
	}

	return (pfn_GetSystemTimePreciseAsFileTime)
		? (pfn_GetSystemTimePreciseAsFileTime(lpSystemTimeAsFileTime), true)
		: false;
}
#endif // WIN8

#endif // _WIN32


/// \brief      Get the current time as milliseconds
///
/// It's relative to some point but not necessarily to the UNIX Epoch.
static uint64_t
mytime_now(void)
{
#if defined(HAVE_CLOCK_GETTIME) && defined(HAVE_CLOCK_MONOTONIC)
	// If CLOCK_MONOTONIC was available at compile time but for some
	// reason isn't at runtime, fallback to CLOCK_REALTIME which
	// according to POSIX is mandatory for all implementations.
	static clockid_t clk_id = CLOCK_MONOTONIC;
	struct timespec tv;
	while (clock_gettime(clk_id, &tv))
		clk_id = CLOCK_REALTIME;

	return (uint64_t)tv.tv_sec * 1000 + (uint64_t)(tv.tv_nsec / 1000000);
#elif defined(_WIN32)
	FILETIME ft;
	if (!win_GetSystemTimePreciseAsFileTime(&ft))
		return (uint64_t)time(NULL) * 1000; // Very bad luck.
	ULARGE_INTEGER li;
	li.HighPart = ft.dwHighDateTime;
	li.LowPart = ft.dwLowDateTime;
	return (li.QuadPart - FILETIME_N_100NS_SINCE_16010101) / (10 * 1000);
#else
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return (uint64_t)tv.tv_sec * 1000 + (uint64_t)(tv.tv_usec / 1000);
#endif
}


extern void
mytime_set_start_time(void)
{
	start_time = mytime_now();
	return;
}


extern uint64_t
mytime_get_elapsed(void)
{
	return mytime_now() - start_time;
}


extern void
mytime_set_flush_time(void)
{
	next_flush = mytime_now() + opt_flush_timeout;
	return;
}


extern int
mytime_get_flush_timeout(void)
{
	if (opt_flush_timeout == 0 || opt_mode != MODE_COMPRESS)
		return -1;

	const uint64_t now = mytime_now();
	if (now >= next_flush)
		return 0;

	const uint64_t remaining = next_flush - now;
	return remaining > INT_MAX ? INT_MAX : (int)remaining;
}
