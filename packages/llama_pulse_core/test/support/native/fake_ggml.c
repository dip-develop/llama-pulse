// Fake `libggml` used by the native loader tests.
//
// It exports only `ggml_backend_load_all_from_path` and records what the
// loader passed it, plus how many `llama_backend_init` calls had happened at
// that moment. The counter is looked up in the already-loaded fake llama
// shim, which is how the test proves the backend registration runs before the
// backend registry is initialised.

#include <stddef.h>
#include <stdio.h>
#include <string.h>

#if !defined(_WIN32)
#include <dlfcn.h>
#endif

#define FAKE_GGML_MAX_PATH 4096

#if defined(__APPLE__)
#define FAKE_LLAMA_LIBRARY "libllama_test.dylib"
#elif defined(_WIN32)
#define FAKE_LLAMA_LIBRARY "llama_test.dll"
#else
#define FAKE_LLAMA_LIBRARY "libllama_test.so"
#endif

static int g_load_calls = 0;
static int g_init_count_at_load = -1;
static char g_last_path[FAKE_GGML_MAX_PATH] = "";

int fake_ggml_load_calls(void) { return g_load_calls; }

int fake_ggml_init_count_at_load(void) { return g_init_count_at_load; }

const char *fake_ggml_last_path(void) { return g_last_path; }

void ggml_backend_load_all_from_path(const char *dir_path) {
    g_load_calls++;
    if (dir_path != NULL) {
        strncpy(g_last_path, dir_path, sizeof g_last_path - 1);
        g_last_path[sizeof g_last_path - 1] = '\0';
    }
#if !defined(_WIN32)
    // Dart opens the main shim with a local scope, so RTLD_DEFAULT cannot see
    // its counter; RTLD_NOLOAD returns the handle of the already-loaded file.
    char composed[FAKE_GGML_MAX_PATH * 2];
    snprintf(composed, sizeof composed, "%s/%s",
             dir_path == NULL ? "" : dir_path, FAKE_LLAMA_LIBRARY);
    void *handle = dlopen(composed, RTLD_NOLOAD | RTLD_LAZY);
    int (*counter)(void) =
        handle == NULL
            ? NULL
            : (int (*)(void)) dlsym(handle, "fake_llama_backend_init_count");
    g_init_count_at_load = counter == NULL ? -1 : counter();
#endif
}
