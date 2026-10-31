// Hermetic stand-in for libllama.
//
// The shim compiles against the vendored v0.8.0 headers and exports every
// symbol `LlamaBindings.lookupAll` resolves, so the open/load path can be
// exercised without a real llama.cpp build. It never touches the filesystem:
// the model path is only recorded, and failures are triggered through
// `fake_llama_set_fail_*` (or the matching `FAKE_LLAMA_FAIL_*` variables).
//
// Every exported `fake_llama_*` getter exists for the Dart tests to read the
// values the session passed into the C API.

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "llama.h"

#define FAKE_MAX_PATH 4096

// ---------------------------------------------------------------------------
// Recorded state.
// ---------------------------------------------------------------------------

static char g_version[256] = "0.8.0";
static int g_version_overridden = 0;

static int g_backend_init_count = 0;
static int g_model_free_count = 0;
static int g_ctx_free_count = 0;

static int32_t g_gpu_layers = -1;
static char g_model_path[FAKE_MAX_PATH] = "";
static uint32_t g_ctx_size = 0;
static uint32_t g_batch_size = 0;
static uint32_t g_ubatch_size = 0;
static int32_t g_threads = 0;
static int32_t g_threads_batch = 0;
static uint32_t g_seq_max = 0;
static bool g_no_perf = true;

// -1 means "fall back to the environment variable".
static int g_fail_model = -1;
static int g_fail_ctx = -1;

// Opaque sentinels: the session only checks for null and passes them back.
static char g_model_sentinel;
static char g_context_sentinel;
static char g_vocab_sentinel;
static char g_memory_sentinel;
static char g_sampler_sentinel;

// ---------------------------------------------------------------------------
// Test control surface.
// ---------------------------------------------------------------------------

void fake_llama_set_version(const char *version) {
    if (version == NULL) {
        g_version_overridden = 0;
        return;
    }
    g_version_overridden = 1;
    snprintf(g_version, sizeof g_version, "%s", version);
}

void fake_llama_set_fail_model(int fail) {
    g_fail_model = fail;
}

void fake_llama_set_fail_ctx(int fail) {
    g_fail_ctx = fail;
}

void fake_llama_reset(void) {
    g_version_overridden = 0;
    g_backend_init_count = 0;
    g_model_free_count = 0;
    g_ctx_free_count = 0;
    g_gpu_layers = -1;
    g_model_path[0] = '\0';
    g_ctx_size = 0;
    g_batch_size = 0;
    g_ubatch_size = 0;
    g_threads = 0;
    g_threads_batch = 0;
    g_seq_max = 0;
    g_no_perf = true;
    g_fail_model = -1;
    g_fail_ctx = -1;
}

int fake_llama_gpu_layers(void) { return g_gpu_layers; }
const char *fake_llama_model_path(void) { return g_model_path; }
int fake_llama_ctx_size(void) { return (int) g_ctx_size; }
int fake_llama_batch_size(void) { return (int) g_batch_size; }
int fake_llama_ubatch_size(void) { return (int) g_ubatch_size; }
int fake_llama_threads(void) { return g_threads; }
int fake_llama_threads_batch(void) { return g_threads_batch; }
int fake_llama_seq_max(void) { return (int) g_seq_max; }
int fake_llama_no_perf(void) { return g_no_perf ? 1 : 0; }
int fake_llama_model_free_count(void) { return g_model_free_count; }
int fake_llama_ctx_free_count(void) { return g_ctx_free_count; }
int fake_llama_backend_init_count(void) { return g_backend_init_count; }

// ---------------------------------------------------------------------------
// llama.cpp API.
// ---------------------------------------------------------------------------

const char *llama_version(void) {
    if (g_version_overridden) {
        return g_version;
    }
    const char *env = getenv("FAKE_LLAMA_VERSION");
    return env != NULL ? env : "0.8.0";
}

void llama_backend_init(void) { g_backend_init_count += 1; }

void llama_backend_free(void) {}

struct llama_model_params llama_model_default_params(void) {
    struct llama_model_params params;
    memset(&params, 0, sizeof params);
    return params;
}

struct llama_context_params llama_context_default_params(void) {
    struct llama_context_params params;
    memset(&params, 0, sizeof params);
    return params;
}

static int fake_fail_model(void) {
    if (g_fail_model >= 0) {
        return g_fail_model;
    }
    return getenv("FAKE_LLAMA_FAIL_MODEL") != NULL;
}

static int fake_fail_ctx(void) {
    if (g_fail_ctx >= 0) {
        return g_fail_ctx;
    }
    return getenv("FAKE_LLAMA_FAIL_CTX") != NULL;
}

struct llama_model *llama_model_load_from_file(
        const char *path,
        struct llama_model_params params) {
    g_gpu_layers = params.n_gpu_layers;
    snprintf(g_model_path, sizeof g_model_path, "%s", path == NULL ? "" : path);
    if (fake_fail_model()) {
        return NULL;
    }
    return (struct llama_model *) &g_model_sentinel;
}

void llama_model_free(struct llama_model *model) {
    (void) model;
    g_model_free_count += 1;
}

const struct llama_vocab *llama_model_get_vocab(const struct llama_model *model) {
    (void) model;
    return (const struct llama_vocab *) &g_vocab_sentinel;
}

int32_t llama_vocab_n_tokens(const struct llama_vocab *vocab) {
    (void) vocab;
    return 32000;
}

bool llama_vocab_is_eog(const struct llama_vocab *vocab, llama_token token) {
    (void) vocab;
    return token == 2;
}

llama_token llama_vocab_eos(const struct llama_vocab *vocab) {
    (void) vocab;
    return 2;
}

struct llama_context *llama_init_from_model(
        struct llama_model *model,
        struct llama_context_params params) {
    (void) model;
    g_ctx_size = params.n_ctx;
    g_batch_size = params.n_batch;
    g_ubatch_size = params.n_ubatch;
    g_threads = params.n_threads;
    g_threads_batch = params.n_threads_batch;
    g_seq_max = params.n_seq_max;
    g_no_perf = params.no_perf;
    if (fake_fail_ctx()) {
        return NULL;
    }
    return (struct llama_context *) &g_context_sentinel;
}

void llama_free(struct llama_context *ctx) {
    (void) ctx;
    g_ctx_free_count += 1;
}

uint32_t llama_n_ctx(const struct llama_context *ctx) {
    (void) ctx;
    return g_ctx_size;
}

uint32_t llama_n_batch(const struct llama_context *ctx) {
    (void) ctx;
    return g_batch_size;
}

int32_t llama_tokenize(
        const struct llama_vocab *vocab,
        const char *text,
        int32_t text_len,
        llama_token *tokens,
        int32_t n_tokens_max,
        bool add_special,
        bool parse_special) {
    (void) vocab;
    (void) text;
    (void) text_len;
    (void) tokens;
    (void) n_tokens_max;
    (void) add_special;
    (void) parse_special;
    return 0;
}

int32_t llama_token_to_piece(
        const struct llama_vocab *vocab,
        llama_token token,
        char *buf,
        int32_t length,
        int32_t lstrip,
        bool special) {
    (void) vocab;
    (void) token;
    (void) buf;
    (void) length;
    (void) lstrip;
    (void) special;
    return 0;
}

struct llama_batch llama_batch_init(
        int32_t n_tokens,
        int32_t embd,
        int32_t n_seq_max) {
    (void) n_tokens;
    (void) embd;
    (void) n_seq_max;
    struct llama_batch batch;
    memset(&batch, 0, sizeof batch);
    return batch;
}

void llama_batch_free(struct llama_batch batch) {
    (void) batch;
}

int32_t llama_decode(struct llama_context *ctx, struct llama_batch batch) {
    (void) ctx;
    (void) batch;
    return 0;
}

llama_memory_t llama_get_memory(const struct llama_context *ctx) {
    (void) ctx;
    return (llama_memory_t) &g_memory_sentinel;
}

void llama_memory_clear(llama_memory_t mem, bool data) {
    (void) mem;
    (void) data;
}

struct llama_sampler *llama_sampler_chain_init(
        struct llama_sampler_chain_params params) {
    (void) params;
    return (struct llama_sampler *) &g_sampler_sentinel;
}

void llama_sampler_chain_add(
        struct llama_sampler *chain,
        struct llama_sampler *smpl) {
    (void) chain;
    (void) smpl;
}

struct llama_sampler *llama_sampler_init_top_k(int32_t k) {
    (void) k;
    return (struct llama_sampler *) &g_sampler_sentinel;
}

struct llama_sampler *llama_sampler_init_top_p(float p, size_t min_keep) {
    (void) p;
    (void) min_keep;
    return (struct llama_sampler *) &g_sampler_sentinel;
}

struct llama_sampler *llama_sampler_init_min_p(float p, size_t min_keep) {
    (void) p;
    (void) min_keep;
    return (struct llama_sampler *) &g_sampler_sentinel;
}

struct llama_sampler *llama_sampler_init_temp(float t) {
    (void) t;
    return (struct llama_sampler *) &g_sampler_sentinel;
}

struct llama_sampler *llama_sampler_init_dist(uint32_t seed) {
    (void) seed;
    return (struct llama_sampler *) &g_sampler_sentinel;
}

llama_token llama_sampler_sample(
        struct llama_sampler *smpl,
        struct llama_context *ctx,
        int32_t idx) {
    (void) smpl;
    (void) ctx;
    (void) idx;
    return 0;
}

void llama_sampler_free(struct llama_sampler *smpl) {
    (void) smpl;
}

struct llama_perf_context_data llama_perf_context(
        const struct llama_context *ctx) {
    (void) ctx;
    struct llama_perf_context_data data;
    memset(&data, 0, sizeof data);
    return data;
}

void llama_perf_context_reset(struct llama_context *ctx) {
    (void) ctx;
}
