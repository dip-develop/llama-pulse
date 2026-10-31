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
// Generation script and recorders.
// ---------------------------------------------------------------------------

#define FAKE_MAX_TOKENS 8192
#define FAKE_MAX_PIECES 256
#define FAKE_MAX_TOKEN_PIECES 128
#define FAKE_PIECE_BYTES 64
#define FAKE_MAX_DECODES 8192

// How many tokens llama_tokenize should produce. Negative values make the
// first probe return that value and the following call fill the buffer.
static int g_tokenize_result = 0;
static int g_tokenize_calls = 0;
static int g_tokenize_probe_pending = 0;

// Token ids the sampler returns, in order.
static int32_t g_tokens[FAKE_MAX_TOKENS];
static int g_token_count = 0;
static int g_sample_index = 0;
static int g_sample_calls = 0;

// Pieces aligned with the indices of g_tokens.
static char g_piece_data[FAKE_MAX_PIECES][FAKE_PIECE_BYTES];
static int g_piece_lengths[FAKE_MAX_PIECES];
static int g_piece_count = 0;

// Raw-byte pieces keyed by token id, used by the UTF-8 split test.
static struct fake_token_piece {
    int32_t token;
    unsigned char bytes[FAKE_PIECE_BYTES];
    int length;
} g_token_pieces[FAKE_MAX_TOKEN_PIECES];
static int g_token_piece_count = 0;

static int g_decode_result = 0;
static int g_decode_calls = 0;
static int g_batch_chunks = 0;
static int g_max_batch_tokens = 0;
static int g_total_batch_tokens = 0;
static int g_first_batch_pos = 0;
static int g_last_batch_pos = 0;
// Last position of every decode call, indexed by call order.
static int g_decode_last_pos[FAKE_MAX_DECODES];
static int g_logits_count = 0;
static int g_logits_mismatch = 0;
static int g_batch_free_count = 0;
static int g_memory_clear_count = 0;
static int g_sampler_init_count = 0;
static int g_sampler_free_count = 0;

static struct llama_perf_context_data g_perf;
static int g_perf_reset_count = 0;

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

void fake_llama_set_tokenize_result(int count) {
    g_tokenize_result = count;
    g_tokenize_probe_pending = 0;
}

void fake_llama_set_tokens(const int32_t *ids, int n) {
    if (n < 0) {
        n = 0;
    }
    if (n > FAKE_MAX_TOKENS) {
        n = FAKE_MAX_TOKENS;
    }
    if (ids != NULL) {
        memcpy(g_tokens, ids, (size_t) n * sizeof(int32_t));
    }
    g_token_count = n;
    g_sample_index = 0;
}

void fake_llama_set_pieces(const char *const *pieces, int n) {
    if (n < 0) {
        n = 0;
    }
    if (n > FAKE_MAX_PIECES) {
        n = FAKE_MAX_PIECES;
    }
    g_piece_count = n;
    for (int i = 0; i < n; i++) {
        const char *piece = pieces == NULL ? NULL : pieces[i];
        int length = 0;
        if (piece != NULL) {
            while (piece[length] != '\0' && length < FAKE_PIECE_BYTES - 1) {
                g_piece_data[i][length] = piece[length];
                length++;
            }
        }
        g_piece_data[i][length] = '\0';
        g_piece_lengths[i] = length;
    }
}

void fake_llama_set_piece_bytes(int token, const uint8_t *bytes, int n) {
    if (n < 0) {
        n = 0;
    }
    if (n > FAKE_PIECE_BYTES) {
        n = FAKE_PIECE_BYTES;
    }
    int slot = -1;
    for (int i = 0; i < g_token_piece_count; i++) {
        if (g_token_pieces[i].token == token) {
            slot = i;
            break;
        }
    }
    if (slot < 0) {
        if (g_token_piece_count >= FAKE_MAX_TOKEN_PIECES) {
            return;
        }
        slot = g_token_piece_count++;
        g_token_pieces[slot].token = token;
    }
    if (bytes != NULL && n > 0) {
        memcpy(g_token_pieces[slot].bytes, bytes, (size_t) n);
    }
    g_token_pieces[slot].length = n;
}

void fake_llama_set_decode_result(int code) {
    g_decode_result = code;
}

void fake_llama_set_sample_index(int idx) {
    g_sample_index = idx;
}

void fake_llama_set_perf(double p_eval_ms, double eval_ms, int n_p_eval,
                         int n_eval) {
    g_perf.t_p_eval_ms = p_eval_ms;
    g_perf.t_eval_ms = eval_ms;
    g_perf.n_p_eval = n_p_eval;
    g_perf.n_eval = n_eval;
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
    g_tokenize_result = 0;
    g_tokenize_calls = 0;
    g_tokenize_probe_pending = 0;
    g_token_count = 0;
    g_sample_index = 0;
    g_sample_calls = 0;
    g_piece_count = 0;
    g_token_piece_count = 0;
    g_decode_result = 0;
    g_decode_calls = 0;
    g_batch_chunks = 0;
    g_max_batch_tokens = 0;
    g_total_batch_tokens = 0;
    g_first_batch_pos = 0;
    g_last_batch_pos = 0;
    memset(g_decode_last_pos, 0, sizeof g_decode_last_pos);
    g_logits_count = 0;
    g_logits_mismatch = 0;
    g_batch_free_count = 0;
    g_memory_clear_count = 0;
    g_sampler_init_count = 0;
    g_sampler_free_count = 0;
    memset(&g_perf, 0, sizeof g_perf);
    g_perf_reset_count = 0;
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

int fake_llama_tokenize_calls(void) { return g_tokenize_calls; }
int fake_llama_decode_calls(void) { return g_decode_calls; }
int fake_llama_batch_nodes(void) { return g_batch_chunks; }
int fake_llama_max_batch_tokens(void) { return g_max_batch_tokens; }
int fake_llama_total_batch_tokens(void) { return g_total_batch_tokens; }
int fake_llama_first_batch_pos(void) { return g_first_batch_pos; }
int fake_llama_last_batch_pos(void) { return g_last_batch_pos; }
int fake_llama_decode_last_pos(int index) {
    if (index < 0 || index >= g_decode_calls || index >= FAKE_MAX_DECODES) {
        return -1;
    }
    return g_decode_last_pos[index];
}
int fake_llama_logits_count(void) { return g_logits_count; }
int fake_llama_logits_last_only(void) { return g_logits_mismatch == 0; }
int fake_llama_batch_free_count(void) { return g_batch_free_count; }
int fake_llama_memory_clear_count(void) { return g_memory_clear_count; }
int fake_llama_sampler_init_count(void) { return g_sampler_init_count; }
int fake_llama_sampler_free_count(void) { return g_sampler_free_count; }
int fake_llama_sample_calls(void) { return g_sample_calls; }
int fake_llama_perf_reset_count(void) { return g_perf_reset_count; }

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
    (void) add_special;
    (void) parse_special;
    g_tokenize_calls += 1;

    int need;
    if (g_tokenize_result < 0) {
        if (!g_tokenize_probe_pending) {
            g_tokenize_probe_pending = 1;
            return g_tokenize_result;
        }
        g_tokenize_probe_pending = 0;
        need = -g_tokenize_result;
    } else {
        need = g_tokenize_result;
    }
    if (need == 0) {
        return 0;
    }
    if (tokens == NULL || n_tokens_max < need) {
        return -need;
    }
    for (int i = 0; i < need; i++) {
        tokens[i] = (i % 9) + 1;
    }
    return need;
}

int32_t llama_token_to_piece(
        const struct llama_vocab *vocab,
        llama_token token,
        char *buf,
        int32_t length,
        int32_t lstrip,
        bool special) {
    (void) vocab;
    (void) lstrip;
    (void) special;

    const unsigned char *source = NULL;
    int source_length = 0;

    for (int i = 0; i < g_token_piece_count; i++) {
        if (g_token_pieces[i].token == token) {
            source = g_token_pieces[i].bytes;
            source_length = g_token_pieces[i].length;
            break;
        }
    }
    if (source == NULL) {
        for (int i = 0; i < g_token_count && i < g_piece_count; i++) {
            if (g_tokens[i] == token) {
                source = (const unsigned char *) g_piece_data[i];
                source_length = g_piece_lengths[i];
                break;
            }
        }
    }
    if (source == NULL || source_length == 0) {
        return 0;
    }
    if (buf == NULL || length < source_length) {
        return -source_length;
    }
    memcpy(buf, source, (size_t) source_length);
    return source_length;
}

struct llama_batch llama_batch_init(
        int32_t n_tokens,
        int32_t embd,
        int32_t n_seq_max) {
    (void) embd;
    if (n_tokens < 0) {
        n_tokens = 0;
    }
    if (n_seq_max < 1) {
        n_seq_max = 1;
    }
    const size_t count = (size_t) (n_tokens > 0 ? n_tokens : 1);
    struct llama_batch batch;
    memset(&batch, 0, sizeof batch);
    batch.n_tokens = n_tokens;
    batch.token = calloc(count, sizeof(llama_token));
    batch.pos = calloc(count, sizeof(llama_pos));
    batch.n_seq_id = calloc(count, sizeof(int32_t));
    batch.seq_id = calloc(count, sizeof(int32_t *));
    batch.logits = calloc(count, sizeof(int8_t));
    for (int32_t i = 0; i < n_tokens; i++) {
        batch.seq_id[i] = calloc((size_t) n_seq_max, sizeof(int32_t));
    }
    return batch;
}

void llama_batch_free(struct llama_batch batch) {
    if (batch.seq_id != NULL) {
        for (int32_t i = 0; i < batch.n_tokens; i++) {
            free(batch.seq_id[i]);
        }
    }
    free(batch.token);
    free(batch.pos);
    free(batch.n_seq_id);
    free(batch.seq_id);
    free(batch.logits);
    g_batch_free_count += 1;
}

int32_t llama_decode(struct llama_context *ctx, struct llama_batch batch) {
    (void) ctx;
    g_decode_calls += 1;
    g_batch_chunks += 1;
    g_total_batch_tokens += batch.n_tokens;
    if (batch.n_tokens > g_max_batch_tokens) {
        g_max_batch_tokens = batch.n_tokens;
    }
    if (batch.n_tokens > 0) {
        if (g_batch_chunks == 1) {
            g_first_batch_pos = batch.pos[0];
        }
        g_last_batch_pos = batch.pos[batch.n_tokens - 1];
        if (g_decode_calls <= FAKE_MAX_DECODES) {
            g_decode_last_pos[g_decode_calls - 1] = g_last_batch_pos;
        }
        for (int32_t i = 0; i < batch.n_tokens; i++) {
            if (batch.logits[i] != 0) {
                g_logits_count += 1;
                if (i != batch.n_tokens - 1) {
                    g_logits_mismatch = 1;
                }
            }
        }
    }
    return g_decode_result;
}

llama_memory_t llama_get_memory(const struct llama_context *ctx) {
    (void) ctx;
    return (llama_memory_t) &g_memory_sentinel;
}

void llama_memory_clear(llama_memory_t mem, bool data) {
    (void) mem;
    (void) data;
    g_memory_clear_count += 1;
}

struct llama_sampler *llama_sampler_chain_init(
        struct llama_sampler_chain_params params) {
    (void) params;
    g_sampler_init_count += 1;
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
    g_sample_calls += 1;
    if (g_sample_index < 0 || g_sample_index >= g_token_count) {
        return 2;
    }
    return g_tokens[g_sample_index++];
}

void llama_sampler_free(struct llama_sampler *smpl) {
    (void) smpl;
    g_sampler_free_count += 1;
}

struct llama_perf_context_data llama_perf_context(
        const struct llama_context *ctx) {
    (void) ctx;
    return g_perf;
}

void llama_perf_context_reset(struct llama_context *ctx) {
    (void) ctx;
    memset(&g_perf, 0, sizeof g_perf);
    g_perf_reset_count += 1;
}
