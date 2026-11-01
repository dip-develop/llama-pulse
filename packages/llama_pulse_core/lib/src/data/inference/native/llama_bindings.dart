// Hand-written FFI bindings for the llama.cpp C API.
//
// Every declaration below mirrors `third_party/llama_cpp/v0.8.0/include/llama.h`
// field for field and argument for argument. The ABI is not taken on faith:
// `test/data/inference/native/abi_layout_test.dart` compiles the real header
// with clang and compares struct sizes plus every field offset against the Dart
// structs. No field may be reordered, renamed or retyped without moving the
// pin; if the test goes red, the binding is wrong, not the test.
//
// This file only declares types. It never opens a dynamic library; the worker
// isolate owns the `ffi.DynamicLibrary` and hands it to
// [LlamaBindings.lookupAll].
//
// ignore_for_file: camel_case_types, non_constant_identifier_names

import 'dart:ffi' as ffi;

// `Utf8` is not part of `dart:ffi`; package:ffi provides the opaque marker plus
// the `toDartString()` extension that callers use on `llama_version()`.
import 'package:ffi/ffi.dart' show Utf8;

/// `struct llama_model` — opaque handle to a loaded model.
final class LlamaModel extends ffi.Opaque {}

/// `struct llama_context` — opaque handle to an inference context.
final class LlamaContext extends ffi.Opaque {}

/// `struct llama_sampler` — opaque handle to a sampler or sampler chain.
final class LlamaSampler extends ffi.Opaque {}

/// `struct llama_vocab` — opaque handle to a model vocabulary.
final class LlamaVocab extends ffi.Opaque {}

/// `struct llama_memory_i` behind `llama_memory_t` — opaque handle to the
/// key/value memory of a context.
final class LlamaMemory extends ffi.Opaque {}

/// Mirrors `struct llama_model_params` (`llama.h`, v0.8.0).
///
/// Field order, and therefore the layout, is checked by the ABI test.
final class LlamaModelParams extends ffi.Struct {
  /// `ggml_backend_dev_t * devices` — NULL-terminated device list.
  external ffi.Pointer<ffi.Pointer<ffi.Void>> devices;

  /// `const struct llama_model_tensor_buft_override * tensor_buft_overrides`.
  ///
  /// Opaque: the binding never dereferences it.
  external ffi.Pointer<ffi.Void> tensorBuftOverrides;

  /// `int32_t n_gpu_layers`.
  @ffi.Int32()
  external int nGpuLayers;

  /// `enum llama_split_mode split_mode`; see [LlamaSplitMode].
  @ffi.Int32()
  external int splitMode;

  /// `enum llama_load_mode load_mode`; see [LlamaLoadMode].
  @ffi.Int32()
  external int loadMode;

  /// `enum llama_lazy_mode lazy_mode`; see [LlamaLazyMode].
  @ffi.Int32()
  external int lazyMode;

  /// `int32_t main_gpu`.
  @ffi.Int32()
  external int mainGpu;

  /// `const float * tensor_split` — per-device offload proportions.
  external ffi.Pointer<ffi.Float> tensorSplit;

  /// `llama_progress_callback progress_callback`.
  ///
  /// Kept as an opaque pointer: no callback is installed by this app.
  external ffi.Pointer<ffi.Void> progressCallback;

  /// `void * progress_callback_user_data`.
  external ffi.Pointer<ffi.Void> progressCallbackUserData;

  /// `const struct llama_model_kv_override * kv_overrides`. Opaque.
  external ffi.Pointer<ffi.Void> kvOverrides;

  /// `bool vocab_only`.
  @ffi.Bool()
  external bool vocabOnly;

  /// `bool check_tensors`.
  @ffi.Bool()
  external bool checkTensors;

  /// `bool use_extra_bufts`.
  @ffi.Bool()
  external bool useExtraBufts;

  /// `bool no_host`.
  @ffi.Bool()
  external bool noHost;

  /// `bool no_alloc`.
  @ffi.Bool()
  external bool noAlloc;

  /// `bool load_mtp`.
  @ffi.Bool()
  external bool loadMtp;
}

/// Mirrors `struct llama_context_params` (`llama.h`, v0.8.0).
///
/// Field order, and therefore the layout, is checked by the ABI test.
final class LlamaContextParams extends ffi.Struct {
  /// `uint32_t n_ctx`.
  @ffi.Uint32()
  external int nCtx;

  /// `uint32_t n_batch`.
  @ffi.Uint32()
  external int nBatch;

  /// `uint32_t n_ubatch`.
  @ffi.Uint32()
  external int nUbatch;

  /// `uint32_t n_seq_max`.
  @ffi.Uint32()
  external int nSeqMax;

  /// `uint32_t n_rs_seq`.
  @ffi.Uint32()
  external int nRsSeq;

  /// `uint32_t n_outputs_max`.
  @ffi.Uint32()
  external int nOutputsMax;

  /// `uint32_t n_outputs_max_per_seq`.
  @ffi.Uint32()
  external int nOutputsMaxPerSeq;

  /// `int32_t n_threads`.
  @ffi.Int32()
  external int nThreads;

  /// `int32_t n_threads_batch`.
  @ffi.Int32()
  external int nThreadsBatch;

  /// `enum llama_context_type ctx_type`; see [LlamaContextType].
  @ffi.Int32()
  external int ctxType;

  /// `enum llama_rope_scaling_type rope_scaling_type`.
  @ffi.Int32()
  external int ropeScalingType;

  /// `enum llama_pooling_type pooling_type`.
  @ffi.Int32()
  external int poolingType;

  /// `enum llama_attention_type attention_type`.
  @ffi.Int32()
  external int attentionType;

  /// `enum llama_flash_attn_type flash_attn_type`.
  @ffi.Int32()
  external int flashAttnType;

  /// `float rope_freq_base`.
  @ffi.Float()
  external double ropeFreqBase;

  /// `float rope_freq_scale`.
  @ffi.Float()
  external double ropeFreqScale;

  /// `float yarn_ext_factor`.
  @ffi.Float()
  external double yarnExtFactor;

  /// `float yarn_attn_factor`.
  @ffi.Float()
  external double yarnAttnFactor;

  /// `float yarn_beta_fast`.
  @ffi.Float()
  external double yarnBetaFast;

  /// `float yarn_beta_slow`.
  @ffi.Float()
  external double yarnBetaSlow;

  /// `uint32_t yarn_orig_ctx`.
  @ffi.Uint32()
  external int yarnOrigCtx;

  /// `float defrag_thold`.
  @ffi.Float()
  external double defragThold;

  /// `ggml_backend_sched_eval_callback cb_eval`.
  ///
  /// Opaque: no evaluation callback is installed by this app.
  external ffi.Pointer<ffi.Void> cbEval;

  /// `void * cb_eval_user_data`.
  external ffi.Pointer<ffi.Void> cbEvalUserData;

  /// `enum ggml_type type_k`; see [GgmlType].
  @ffi.Int32()
  external int typeK;

  /// `enum ggml_type type_v`.
  @ffi.Int32()
  external int typeV;

  /// `size_t moe_cache_size`.
  @ffi.Size()
  external int moeCacheSize;

  /// `ggml_abort_callback abort_callback`. Opaque; never installed.
  external ffi.Pointer<ffi.Void> abortCallback;

  /// `void * abort_callback_data`.
  external ffi.Pointer<ffi.Void> abortCallbackData;

  /// `bool embeddings`.
  @ffi.Bool()
  external bool embeddings;

  /// `bool offload_kqv`.
  @ffi.Bool()
  external bool offloadKqv;

  /// `bool no_perf`.
  @ffi.Bool()
  external bool noPerf;

  /// `bool op_offload`.
  @ffi.Bool()
  external bool opOffload;

  /// `bool swa_full`.
  @ffi.Bool()
  external bool swaFull;

  /// `bool kv_unified`.
  @ffi.Bool()
  external bool kvUnified;

  /// `struct llama_sampler_seq_config * samplers` — opaque; unused.
  external ffi.Pointer<ffi.Void> samplers;

  /// `size_t n_samplers`.
  @ffi.Size()
  external int nSamplers;

  /// `struct llama_context * ctx_other` — source/target/parent context.
  external ffi.Pointer<LlamaContext> ctxOther;
}

/// Mirrors `struct llama_batch` (`llama.h`, v0.8.0).
///
/// Passed and returned by value, so the layout matters twice over.
final class LlamaBatch extends ffi.Struct {
  /// `int32_t n_tokens`.
  @ffi.Int32()
  external int nTokens;

  /// `llama_token * token` (`int32_t *`).
  external ffi.Pointer<ffi.Int32> token;

  /// `float * embd`.
  external ffi.Pointer<ffi.Float> embd;

  /// `llama_pos * pos` (`int32_t *`).
  external ffi.Pointer<ffi.Int32> pos;

  /// `int32_t * n_seq_id`.
  external ffi.Pointer<ffi.Int32> nSeqId;

  /// `llama_seq_id ** seq_id` (`int32_t **`).
  external ffi.Pointer<ffi.Pointer<ffi.Int32>> seqId;

  /// `int8_t * logits`.
  external ffi.Pointer<ffi.Int8> logits;
}

/// Mirrors `struct llama_sampler_chain_params` (`llama.h`, v0.8.0).
final class LlamaSamplerChainParams extends ffi.Struct {
  /// `bool no_perf`.
  @ffi.Bool()
  external bool noPerf;
}

/// Mirrors `struct llama_chat_message` (`llama.h`, v0.8.0).
///
/// One entry of the chat passed to `llama_chat_apply_template`.
final class LlamaChatMessage extends ffi.Struct {
  /// `const char * role`.
  external ffi.Pointer<ffi.Char> role;

  /// `const char * content`.
  external ffi.Pointer<ffi.Char> content;
}

/// Mirrors `struct llama_perf_context_data` (`llama.h`, v0.8.0).
final class LlamaPerfContextData extends ffi.Struct {
  /// `double t_start_ms`.
  @ffi.Double()
  external double tStartMs;

  /// `double t_load_ms`.
  @ffi.Double()
  external double tLoadMs;

  /// `double t_p_eval_ms`.
  @ffi.Double()
  external double tPEvalMs;

  /// `double t_eval_ms`.
  @ffi.Double()
  external double tEvalMs;

  /// `int32_t n_p_eval`.
  @ffi.Int32()
  external int nPEval;

  /// `int32_t n_eval`.
  @ffi.Int32()
  external int nEval;

  /// `int32_t n_reused`.
  @ffi.Int32()
  external int nReused;

  /// `int32_t n_reallocs_same`.
  @ffi.Int32()
  external int nReallocsSame;

  /// `int32_t n_reallocs_diff`.
  @ffi.Int32()
  external int nReallocsDiff;
}

/// `enum llama_split_mode`.
abstract final class LlamaSplitMode {
  /// `LLAMA_SPLIT_MODE_NONE` — single GPU.
  static const int none = 0;

  /// `LLAMA_SPLIT_MODE_LAYER`.
  static const int layer = 1;

  /// `LLAMA_SPLIT_MODE_ROW`.
  static const int row = 2;

  /// `LLAMA_SPLIT_MODE_TENSOR`.
  static const int tensor = 3;
}

/// `enum llama_load_mode`.
abstract final class LlamaLoadMode {
  /// `LLAMA_LOAD_MODE_AUTO`.
  static const int auto = -1;

  /// `LLAMA_LOAD_MODE_NONE`.
  static const int none = 0;

  /// `LLAMA_LOAD_MODE_MMAP`.
  static const int mmap = 1;

  /// `LLAMA_LOAD_MODE_MLOCK`.
  static const int mlock = 2;

  /// `LLAMA_LOAD_MODE_MMAP_MLOCK`.
  static const int mmapMlock = 3;

  /// `LLAMA_LOAD_MODE_DIRECT_IO`.
  static const int directIo = 4;
}

/// `enum llama_lazy_mode`.
abstract final class LlamaLazyMode {
  /// `LLAMA_LAZY_MODE_OFF`.
  static const int off = 0;

  /// `LLAMA_LAZY_MODE_AUTO`.
  static const int auto = 1;

  /// `LLAMA_LAZY_MODE_ON`.
  static const int on = 2;
}

/// `enum llama_context_type`.
abstract final class LlamaContextType {
  /// `LLAMA_CONTEXT_TYPE_DEFAULT` (spelled `defaultType` because `default` is
  /// reserved in Dart).
  static const int defaultType = 0;

  /// `LLAMA_CONTEXT_TYPE_MTP`.
  static const int mtp = 1;
}

/// `enum llama_rope_scaling_type`.
abstract final class LlamaRopeScalingType {
  /// `LLAMA_ROPE_SCALING_TYPE_UNSPECIFIED`.
  static const int unspecified = -1;

  /// `LLAMA_ROPE_SCALING_TYPE_NONE`.
  static const int none = 0;

  /// `LLAMA_ROPE_SCALING_TYPE_LINEAR`.
  static const int linear = 1;

  /// `LLAMA_ROPE_SCALING_TYPE_YARN`.
  static const int yarn = 2;

  /// `LLAMA_ROPE_SCALING_TYPE_LONGROPE`.
  static const int longrope = 3;

  /// `LLAMA_ROPE_SCALING_TYPE_MAX_VALUE` — an alias of [longrope].
  static const int maxValue = 3;
}

/// `enum llama_pooling_type`.
abstract final class LlamaPoolingType {
  /// `LLAMA_POOLING_TYPE_UNSPECIFIED`.
  static const int unspecified = -1;

  /// `LLAMA_POOLING_TYPE_NONE`.
  static const int none = 0;

  /// `LLAMA_POOLING_TYPE_MEAN`.
  static const int mean = 1;

  /// `LLAMA_POOLING_TYPE_CLS`.
  static const int cls = 2;

  /// `LLAMA_POOLING_TYPE_LAST`.
  static const int last = 3;

  /// `LLAMA_POOLING_TYPE_RANK`.
  static const int rank = 4;
}

/// `enum llama_attention_type`.
abstract final class LlamaAttentionType {
  /// `LLAMA_ATTENTION_TYPE_UNSPECIFIED`.
  static const int unspecified = -1;

  /// `LLAMA_ATTENTION_TYPE_CAUSAL`.
  static const int causal = 0;

  /// `LLAMA_ATTENTION_TYPE_NON_CAUSAL`.
  static const int nonCausal = 1;
}

/// `enum llama_flash_attn_type`.
abstract final class LlamaFlashAttnType {
  /// `LLAMA_FLASH_ATTN_TYPE_AUTO`.
  static const int auto = -1;

  /// `LLAMA_FLASH_ATTN_TYPE_DISABLED`.
  static const int disabled = 0;

  /// `LLAMA_FLASH_ATTN_TYPE_ENABLED`.
  static const int enabled = 1;
}

/// `enum ggml_type` from `ggml.h` (the ggml version pinned with llama.cpp).
///
/// Only the values a caller may put into `type_k`/`type_v` are spelled out;
/// the removed slots (4, 5, 31–33, 36–38) are intentionally absent, exactly as
/// in the header.
abstract final class GgmlType {
  /// `GGML_TYPE_F32`.
  static const int f32 = 0;

  /// `GGML_TYPE_F16`.
  static const int f16 = 1;

  /// `GGML_TYPE_Q4_0`.
  static const int q4_0 = 2;

  /// `GGML_TYPE_Q4_1`.
  static const int q4_1 = 3;

  /// `GGML_TYPE_Q5_0`.
  static const int q5_0 = 6;

  /// `GGML_TYPE_Q5_1`.
  static const int q5_1 = 7;

  /// `GGML_TYPE_Q8_0`.
  static const int q8_0 = 8;

  /// `GGML_TYPE_Q8_1`.
  static const int q8_1 = 9;

  /// `GGML_TYPE_Q2_K`.
  static const int q2K = 10;

  /// `GGML_TYPE_Q3_K`.
  static const int q3K = 11;

  /// `GGML_TYPE_Q4_K`.
  static const int q4K = 12;

  /// `GGML_TYPE_Q5_K`.
  static const int q5K = 13;

  /// `GGML_TYPE_Q6_K`.
  static const int q6K = 14;

  /// `GGML_TYPE_Q8_K`.
  static const int q8K = 15;

  /// `GGML_TYPE_IQ2_XXS`.
  static const int iq2Xxs = 16;

  /// `GGML_TYPE_IQ2_XS`.
  static const int iq2Xs = 17;

  /// `GGML_TYPE_IQ3_XXS`.
  static const int iq3Xxs = 18;

  /// `GGML_TYPE_IQ1_S`.
  static const int iq1S = 19;

  /// `GGML_TYPE_IQ4_NL`.
  static const int iq4Nl = 20;

  /// `GGML_TYPE_IQ3_S`.
  static const int iq3S = 21;

  /// `GGML_TYPE_IQ2_S`.
  static const int iq2S = 22;

  /// `GGML_TYPE_IQ4_XS`.
  static const int iq4Xs = 23;

  /// `GGML_TYPE_I8`.
  static const int i8 = 24;

  /// `GGML_TYPE_I16`.
  static const int i16 = 25;

  /// `GGML_TYPE_I32`.
  static const int i32 = 26;

  /// `GGML_TYPE_I64`.
  static const int i64 = 27;

  /// `GGML_TYPE_F64`.
  static const int f64 = 28;

  /// `GGML_TYPE_IQ1_M`.
  static const int iq1M = 29;

  /// `GGML_TYPE_BF16`.
  static const int bf16 = 30;

  /// `GGML_TYPE_TQ1_0`.
  static const int tq1_0 = 34;

  /// `GGML_TYPE_TQ2_0`.
  static const int tq2_0 = 35;

  /// `GGML_TYPE_MXFP4`.
  static const int mxfp4 = 39;

  /// `GGML_TYPE_NVFP4`.
  static const int nvfp4 = 40;

  /// `GGML_TYPE_Q1_0`.
  static const int q1_0 = 41;

  /// `GGML_TYPE_Q2_0`.
  static const int q2_0 = 42;

  /// `GGML_TYPE_COUNT` — not a real type, the number of entries.
  static const int count = 43;
}

// ---------------------------------------------------------------------------
// Function signatures.
//
// Each C API function has a native (`...C`) signature and the matching Dart
// signature. `ffi.Char` is used for C `char *` buffers, `ffi.Size` for
// `size_t`, and struct-by-value parameters stay plain Dart classes.
// ---------------------------------------------------------------------------

/// `const char * llama_version(void)`.
typedef LlamaVersionC = ffi.Pointer<Utf8> Function();

/// Dart signature of `llama_version`.
typedef LlamaVersion = ffi.Pointer<Utf8> Function();

/// `void llama_backend_init(void)`.
typedef LlamaBackendInitC = ffi.Void Function();

/// Dart signature of `llama_backend_init`.
typedef LlamaBackendInit = void Function();

/// `void llama_backend_free(void)`.
typedef LlamaBackendFreeC = ffi.Void Function();

/// Dart signature of `llama_backend_free`.
typedef LlamaBackendFree = void Function();

/// `struct llama_model_params llama_model_default_params(void)`.
typedef LlamaModelDefaultParamsC = LlamaModelParams Function();

/// Dart signature of `llama_model_default_params`.
typedef LlamaModelDefaultParams = LlamaModelParams Function();

/// `struct llama_model * llama_model_load_from_file(const char *, params)`.
typedef LlamaModelLoadFromFileC = ffi.Pointer<LlamaModel> Function(
  ffi.Pointer<ffi.Char>,
  LlamaModelParams,
);

/// Dart signature of `llama_model_load_from_file`.
typedef LlamaModelLoadFromFile = ffi.Pointer<LlamaModel> Function(
  ffi.Pointer<ffi.Char>,
  LlamaModelParams,
);

/// `void llama_model_free(struct llama_model *)`.
typedef LlamaModelFreeC = ffi.Void Function(ffi.Pointer<LlamaModel>);

/// Dart signature of `llama_model_free`.
typedef LlamaModelFree = void Function(ffi.Pointer<LlamaModel>);

/// `const struct llama_vocab * llama_model_get_vocab(const llama_model *)`.
typedef LlamaModelGetVocabC = ffi.Pointer<LlamaVocab> Function(
  ffi.Pointer<LlamaModel>,
);

/// Dart signature of `llama_model_get_vocab`.
typedef LlamaModelGetVocab = ffi.Pointer<LlamaVocab> Function(
  ffi.Pointer<LlamaModel>,
);

/// `const char * llama_model_chat_template(const struct llama_model *,
/// const char *name)`.
typedef LlamaModelChatTemplateC = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<LlamaModel>,
  ffi.Pointer<ffi.Char>,
);

/// Dart signature of `llama_model_chat_template`.
typedef LlamaModelChatTemplate = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<LlamaModel>,
  ffi.Pointer<ffi.Char>,
);

/// `int32_t llama_chat_apply_template(const char * tmpl,
/// const struct llama_chat_message * chat, size_t n_msg, bool add_ass,
/// char * buf, int32_t length)`.
typedef LlamaChatApplyTemplateC = ffi.Int32 Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<LlamaChatMessage>,
  ffi.Size,
  ffi.Bool,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
);

/// Dart signature of `llama_chat_apply_template`.
typedef LlamaChatApplyTemplate = int Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<LlamaChatMessage>,
  int,
  bool,
  ffi.Pointer<ffi.Char>,
  int,
);

/// `int32_t llama_vocab_n_tokens(const struct llama_vocab *)`.
typedef LlamaVocabNTokensC = ffi.Int32 Function(ffi.Pointer<LlamaVocab>);

/// Dart signature of `llama_vocab_n_tokens`.
typedef LlamaVocabNTokens = int Function(ffi.Pointer<LlamaVocab>);

/// `bool llama_vocab_is_eog(const struct llama_vocab *, llama_token)`.
typedef LlamaVocabIsEogC = ffi.Bool Function(
  ffi.Pointer<LlamaVocab>,
  ffi.Int32,
);

/// Dart signature of `llama_vocab_is_eog`.
typedef LlamaVocabIsEog = bool Function(ffi.Pointer<LlamaVocab>, int);

/// `llama_token llama_vocab_eos(const struct llama_vocab *)`.
typedef LlamaVocabEosC = ffi.Int32 Function(ffi.Pointer<LlamaVocab>);

/// Dart signature of `llama_vocab_eos`.
typedef LlamaVocabEos = int Function(ffi.Pointer<LlamaVocab>);

/// `struct llama_context_params llama_context_default_params(void)`.
typedef LlamaContextDefaultParamsC = LlamaContextParams Function();

/// Dart signature of `llama_context_default_params`.
typedef LlamaContextDefaultParams = LlamaContextParams Function();

/// `struct llama_context * llama_init_from_model(model, params)`.
typedef LlamaInitFromModelC = ffi.Pointer<LlamaContext> Function(
  ffi.Pointer<LlamaModel>,
  LlamaContextParams,
);

/// Dart signature of `llama_init_from_model`.
typedef LlamaInitFromModel = ffi.Pointer<LlamaContext> Function(
  ffi.Pointer<LlamaModel>,
  LlamaContextParams,
);

/// `void llama_free(struct llama_context *)`.
typedef LlamaFreeC = ffi.Void Function(ffi.Pointer<LlamaContext>);

/// Dart signature of `llama_free`.
typedef LlamaFree = void Function(ffi.Pointer<LlamaContext>);

/// `uint32_t llama_n_ctx(const struct llama_context *)`.
typedef LlamaNCtxC = ffi.Uint32 Function(ffi.Pointer<LlamaContext>);

/// Dart signature of `llama_n_ctx`.
typedef LlamaNCtx = int Function(ffi.Pointer<LlamaContext>);

/// `uint32_t llama_n_batch(const struct llama_context *)`.
typedef LlamaNBatchC = ffi.Uint32 Function(ffi.Pointer<LlamaContext>);

/// Dart signature of `llama_n_batch`.
typedef LlamaNBatch = int Function(ffi.Pointer<LlamaContext>);

/// `int32_t llama_tokenize(vocab, text, text_len, tokens, n_tokens_max,
/// add_special, parse_special)`.
typedef LlamaTokenizeC = ffi.Int32 Function(
  ffi.Pointer<LlamaVocab>,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Pointer<ffi.Int32>,
  ffi.Int32,
  ffi.Bool,
  ffi.Bool,
);

/// Dart signature of `llama_tokenize`.
typedef LlamaTokenize = int Function(
  ffi.Pointer<LlamaVocab>,
  ffi.Pointer<ffi.Char>,
  int,
  ffi.Pointer<ffi.Int32>,
  int,
  bool,
  bool,
);

/// `int32_t llama_token_to_piece(vocab, token, buf, length, lstrip, special)`.
typedef LlamaTokenToPieceC = ffi.Int32 Function(
  ffi.Pointer<LlamaVocab>,
  ffi.Int32,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Int32,
  ffi.Bool,
);

/// Dart signature of `llama_token_to_piece`.
typedef LlamaTokenToPiece = int Function(
  ffi.Pointer<LlamaVocab>,
  int,
  ffi.Pointer<ffi.Char>,
  int,
  int,
  bool,
);

/// `struct llama_batch llama_batch_init(int32_t n_tokens, int32_t embd,
/// int32_t n_seq_max)`.
typedef LlamaBatchInitC = LlamaBatch Function(ffi.Int32, ffi.Int32, ffi.Int32);

/// Dart signature of `llama_batch_init`.
typedef LlamaBatchInit = LlamaBatch Function(int, int, int);

/// `void llama_batch_free(struct llama_batch batch)`.
typedef LlamaBatchFreeC = ffi.Void Function(LlamaBatch);

/// Dart signature of `llama_batch_free`.
typedef LlamaBatchFree = void Function(LlamaBatch);

/// `int32_t llama_decode(struct llama_context *, struct llama_batch)`.
typedef LlamaDecodeC = ffi.Int32 Function(
  ffi.Pointer<LlamaContext>,
  LlamaBatch,
);

/// Dart signature of `llama_decode`.
typedef LlamaDecode = int Function(ffi.Pointer<LlamaContext>, LlamaBatch);

/// `llama_memory_t llama_get_memory(const struct llama_context *)`.
typedef LlamaGetMemoryC = ffi.Pointer<LlamaMemory> Function(
  ffi.Pointer<LlamaContext>,
);

/// Dart signature of `llama_get_memory`.
typedef LlamaGetMemory = ffi.Pointer<LlamaMemory> Function(
  ffi.Pointer<LlamaContext>,
);

/// `void llama_memory_clear(llama_memory_t mem, bool data)`.
typedef LlamaMemoryClearC = ffi.Void Function(
  ffi.Pointer<LlamaMemory>,
  ffi.Bool,
);

/// Dart signature of `llama_memory_clear`.
typedef LlamaMemoryClear = void Function(ffi.Pointer<LlamaMemory>, bool);

/// `struct llama_sampler * llama_sampler_chain_init(params)`.
typedef LlamaSamplerChainInitC = ffi.Pointer<LlamaSampler> Function(
  LlamaSamplerChainParams,
);

/// Dart signature of `llama_sampler_chain_init`.
typedef LlamaSamplerChainInit = ffi.Pointer<LlamaSampler> Function(
  LlamaSamplerChainParams,
);

/// `void llama_sampler_chain_add(struct llama_sampler * chain, smpl)`.
typedef LlamaSamplerChainAddC = ffi.Void Function(
  ffi.Pointer<LlamaSampler>,
  ffi.Pointer<LlamaSampler>,
);

/// Dart signature of `llama_sampler_chain_add`.
typedef LlamaSamplerChainAdd = void Function(
  ffi.Pointer<LlamaSampler>,
  ffi.Pointer<LlamaSampler>,
);

/// `struct llama_sampler * llama_sampler_init_top_k(int32_t k)`.
typedef LlamaSamplerInitTopKC = ffi.Pointer<LlamaSampler> Function(ffi.Int32);

/// Dart signature of `llama_sampler_init_top_k`.
typedef LlamaSamplerInitTopK = ffi.Pointer<LlamaSampler> Function(int);

/// `struct llama_sampler * llama_sampler_init_top_p(float p, size_t)`.
typedef LlamaSamplerInitTopPC = ffi.Pointer<LlamaSampler> Function(
  ffi.Float,
  ffi.Size,
);

/// Dart signature of `llama_sampler_init_top_p`.
typedef LlamaSamplerInitTopP = ffi.Pointer<LlamaSampler> Function(double, int);

/// `struct llama_sampler * llama_sampler_init_min_p(float p, size_t)`.
typedef LlamaSamplerInitMinPC = ffi.Pointer<LlamaSampler> Function(
  ffi.Float,
  ffi.Size,
);

/// Dart signature of `llama_sampler_init_min_p`.
typedef LlamaSamplerInitMinP = ffi.Pointer<LlamaSampler> Function(double, int);

/// `struct llama_sampler * llama_sampler_init_temp(float t)`.
typedef LlamaSamplerInitTempC = ffi.Pointer<LlamaSampler> Function(ffi.Float);

/// Dart signature of `llama_sampler_init_temp`.
typedef LlamaSamplerInitTemp = ffi.Pointer<LlamaSampler> Function(double);

/// `struct llama_sampler * llama_sampler_init_dist(uint32_t seed)`.
typedef LlamaSamplerInitDistC = ffi.Pointer<LlamaSampler> Function(ffi.Uint32);

/// Dart signature of `llama_sampler_init_dist`.
typedef LlamaSamplerInitDist = ffi.Pointer<LlamaSampler> Function(int);

/// `llama_token llama_sampler_sample(smpl, ctx, int32_t idx)`.
typedef LlamaSamplerSampleC = ffi.Int32 Function(
  ffi.Pointer<LlamaSampler>,
  ffi.Pointer<LlamaContext>,
  ffi.Int32,
);

/// Dart signature of `llama_sampler_sample`.
typedef LlamaSamplerSample = int Function(
  ffi.Pointer<LlamaSampler>,
  ffi.Pointer<LlamaContext>,
  int,
);

/// `void llama_sampler_free(struct llama_sampler *)`.
typedef LlamaSamplerFreeC = ffi.Void Function(ffi.Pointer<LlamaSampler>);

/// Dart signature of `llama_sampler_free`.
typedef LlamaSamplerFree = void Function(ffi.Pointer<LlamaSampler>);

/// `struct llama_perf_context_data llama_perf_context(const llama_context *)`.
typedef LlamaPerfContextC = LlamaPerfContextData Function(
  ffi.Pointer<LlamaContext>,
);

/// Dart signature of `llama_perf_context`.
typedef LlamaPerfContext = LlamaPerfContextData Function(
  ffi.Pointer<LlamaContext>,
);

/// `void llama_perf_context_reset(struct llama_context *)`.
typedef LlamaPerfContextResetC = ffi.Void Function(ffi.Pointer<LlamaContext>);

/// Dart signature of `llama_perf_context_reset`.
typedef LlamaPerfContextReset = void Function(ffi.Pointer<LlamaContext>);

/// The set of llama.cpp functions this app calls, bound lazily by name.
///
/// Construct one instance, call [lookupAll] with the library the worker
/// resolved, then read the typed getters. A getter throws [StateError] when its
/// symbol was never looked up, so a missing function fails at the call site
/// instead of returning a null pointer.
final class LlamaBindings {
  ffi.Pointer<ffi.NativeFunction<LlamaVersionC>>? _llamaVersion;
  ffi.Pointer<ffi.NativeFunction<LlamaBackendInitC>>? _llamaBackendInit;
  ffi.Pointer<ffi.NativeFunction<LlamaBackendFreeC>>? _llamaBackendFree;
  ffi.Pointer<ffi.NativeFunction<LlamaModelDefaultParamsC>>?
  _llamaModelDefaultParams;
  ffi.Pointer<ffi.NativeFunction<LlamaModelLoadFromFileC>>?
  _llamaModelLoadFromFile;
  ffi.Pointer<ffi.NativeFunction<LlamaModelFreeC>>? _llamaModelFree;
  ffi.Pointer<ffi.NativeFunction<LlamaModelGetVocabC>>? _llamaModelGetVocab;
  ffi.Pointer<ffi.NativeFunction<LlamaModelChatTemplateC>>?
  _llamaModelChatTemplate;
  ffi.Pointer<ffi.NativeFunction<LlamaChatApplyTemplateC>>?
  _llamaChatApplyTemplate;
  ffi.Pointer<ffi.NativeFunction<LlamaVocabNTokensC>>? _llamaVocabNTokens;
  ffi.Pointer<ffi.NativeFunction<LlamaVocabIsEogC>>? _llamaVocabIsEog;
  ffi.Pointer<ffi.NativeFunction<LlamaVocabEosC>>? _llamaVocabEos;
  ffi.Pointer<ffi.NativeFunction<LlamaContextDefaultParamsC>>?
  _llamaContextDefaultParams;
  ffi.Pointer<ffi.NativeFunction<LlamaInitFromModelC>>? _llamaInitFromModel;
  ffi.Pointer<ffi.NativeFunction<LlamaFreeC>>? _llamaFree;
  ffi.Pointer<ffi.NativeFunction<LlamaNCtxC>>? _llamaNCtx;
  ffi.Pointer<ffi.NativeFunction<LlamaNBatchC>>? _llamaNBatch;
  ffi.Pointer<ffi.NativeFunction<LlamaTokenizeC>>? _llamaTokenize;
  ffi.Pointer<ffi.NativeFunction<LlamaTokenToPieceC>>? _llamaTokenToPiece;
  ffi.Pointer<ffi.NativeFunction<LlamaBatchInitC>>? _llamaBatchInit;
  ffi.Pointer<ffi.NativeFunction<LlamaBatchFreeC>>? _llamaBatchFree;
  ffi.Pointer<ffi.NativeFunction<LlamaDecodeC>>? _llamaDecode;
  ffi.Pointer<ffi.NativeFunction<LlamaGetMemoryC>>? _llamaGetMemory;
  ffi.Pointer<ffi.NativeFunction<LlamaMemoryClearC>>? _llamaMemoryClear;
  ffi.Pointer<ffi.NativeFunction<LlamaSamplerChainInitC>>?
  _llamaSamplerChainInit;
  ffi.Pointer<ffi.NativeFunction<LlamaSamplerChainAddC>>? _llamaSamplerChainAdd;
  ffi.Pointer<ffi.NativeFunction<LlamaSamplerInitTopKC>>? _llamaSamplerInitTopK;
  ffi.Pointer<ffi.NativeFunction<LlamaSamplerInitTopPC>>? _llamaSamplerInitTopP;
  ffi.Pointer<ffi.NativeFunction<LlamaSamplerInitMinPC>>? _llamaSamplerInitMinP;
  ffi.Pointer<ffi.NativeFunction<LlamaSamplerInitTempC>>? _llamaSamplerInitTemp;
  ffi.Pointer<ffi.NativeFunction<LlamaSamplerInitDistC>>? _llamaSamplerInitDist;
  ffi.Pointer<ffi.NativeFunction<LlamaSamplerSampleC>>? _llamaSamplerSample;
  ffi.Pointer<ffi.NativeFunction<LlamaSamplerFreeC>>? _llamaSamplerFree;
  ffi.Pointer<ffi.NativeFunction<LlamaPerfContextC>>? _llamaPerfContext;
  ffi.Pointer<ffi.NativeFunction<LlamaPerfContextResetC>>?
  _llamaPerfContextReset;

  /// Resolves every binding in [library], replacing any previous lookup.
  ///
  /// Throws [ArgumentError] from `DynamicLibrary.lookup` when a symbol is
  /// missing, which means the library is not the pinned llama.cpp build.
  void lookupAll(ffi.DynamicLibrary library) {
    _llamaVersion = library.lookup<ffi.NativeFunction<LlamaVersionC>>(
      'llama_version',
    );
    _llamaBackendInit = library.lookup<ffi.NativeFunction<LlamaBackendInitC>>(
      'llama_backend_init',
    );
    _llamaBackendFree = library.lookup<ffi.NativeFunction<LlamaBackendFreeC>>(
      'llama_backend_free',
    );
    _llamaModelDefaultParams = library
        .lookup<ffi.NativeFunction<LlamaModelDefaultParamsC>>(
          'llama_model_default_params',
        );
    _llamaModelLoadFromFile = library
        .lookup<ffi.NativeFunction<LlamaModelLoadFromFileC>>(
          'llama_model_load_from_file',
        );
    _llamaModelFree = library.lookup<ffi.NativeFunction<LlamaModelFreeC>>(
      'llama_model_free',
    );
    _llamaModelGetVocab = library
        .lookup<ffi.NativeFunction<LlamaModelGetVocabC>>(
          'llama_model_get_vocab',
        );
    _llamaModelChatTemplate = library
        .lookup<ffi.NativeFunction<LlamaModelChatTemplateC>>(
          'llama_model_chat_template',
        );
    _llamaChatApplyTemplate = library
        .lookup<ffi.NativeFunction<LlamaChatApplyTemplateC>>(
          'llama_chat_apply_template',
        );
    _llamaVocabNTokens = library.lookup<ffi.NativeFunction<LlamaVocabNTokensC>>(
      'llama_vocab_n_tokens',
    );
    _llamaVocabIsEog = library.lookup<ffi.NativeFunction<LlamaVocabIsEogC>>(
      'llama_vocab_is_eog',
    );
    _llamaVocabEos = library.lookup<ffi.NativeFunction<LlamaVocabEosC>>(
      'llama_vocab_eos',
    );
    _llamaContextDefaultParams = library
        .lookup<ffi.NativeFunction<LlamaContextDefaultParamsC>>(
          'llama_context_default_params',
        );
    _llamaInitFromModel = library
        .lookup<ffi.NativeFunction<LlamaInitFromModelC>>(
          'llama_init_from_model',
        );
    _llamaFree = library.lookup<ffi.NativeFunction<LlamaFreeC>>('llama_free');
    _llamaNCtx = library.lookup<ffi.NativeFunction<LlamaNCtxC>>('llama_n_ctx');
    _llamaNBatch = library.lookup<ffi.NativeFunction<LlamaNBatchC>>(
      'llama_n_batch',
    );
    _llamaTokenize = library.lookup<ffi.NativeFunction<LlamaTokenizeC>>(
      'llama_tokenize',
    );
    _llamaTokenToPiece = library.lookup<ffi.NativeFunction<LlamaTokenToPieceC>>(
      'llama_token_to_piece',
    );
    _llamaBatchInit = library.lookup<ffi.NativeFunction<LlamaBatchInitC>>(
      'llama_batch_init',
    );
    _llamaBatchFree = library.lookup<ffi.NativeFunction<LlamaBatchFreeC>>(
      'llama_batch_free',
    );
    _llamaDecode = library.lookup<ffi.NativeFunction<LlamaDecodeC>>(
      'llama_decode',
    );
    _llamaGetMemory = library.lookup<ffi.NativeFunction<LlamaGetMemoryC>>(
      'llama_get_memory',
    );
    _llamaMemoryClear = library.lookup<ffi.NativeFunction<LlamaMemoryClearC>>(
      'llama_memory_clear',
    );
    _llamaSamplerChainInit = library
        .lookup<ffi.NativeFunction<LlamaSamplerChainInitC>>(
          'llama_sampler_chain_init',
        );
    _llamaSamplerChainAdd = library
        .lookup<ffi.NativeFunction<LlamaSamplerChainAddC>>(
          'llama_sampler_chain_add',
        );
    _llamaSamplerInitTopK = library
        .lookup<ffi.NativeFunction<LlamaSamplerInitTopKC>>(
          'llama_sampler_init_top_k',
        );
    _llamaSamplerInitTopP = library
        .lookup<ffi.NativeFunction<LlamaSamplerInitTopPC>>(
          'llama_sampler_init_top_p',
        );
    _llamaSamplerInitMinP = library
        .lookup<ffi.NativeFunction<LlamaSamplerInitMinPC>>(
          'llama_sampler_init_min_p',
        );
    _llamaSamplerInitTemp = library
        .lookup<ffi.NativeFunction<LlamaSamplerInitTempC>>(
          'llama_sampler_init_temp',
        );
    _llamaSamplerInitDist = library
        .lookup<ffi.NativeFunction<LlamaSamplerInitDistC>>(
          'llama_sampler_init_dist',
        );
    _llamaSamplerSample = library
        .lookup<ffi.NativeFunction<LlamaSamplerSampleC>>(
          'llama_sampler_sample',
        );
    _llamaSamplerFree = library.lookup<ffi.NativeFunction<LlamaSamplerFreeC>>(
      'llama_sampler_free',
    );
    _llamaPerfContext = library.lookup<ffi.NativeFunction<LlamaPerfContextC>>(
      'llama_perf_context',
    );
    _llamaPerfContextReset = library
        .lookup<ffi.NativeFunction<LlamaPerfContextResetC>>(
          'llama_perf_context_reset',
        );
  }

  /// `const char * llama_version(void)`.
  LlamaVersion get llamaVersion =>
      _require(_llamaVersion, 'llama_version').asFunction<LlamaVersion>();

  /// `void llama_backend_init(void)`.
  LlamaBackendInit get llamaBackendInit => _require(
    _llamaBackendInit,
    'llama_backend_init',
  ).asFunction<LlamaBackendInit>();

  /// `void llama_backend_free(void)`.
  LlamaBackendFree get llamaBackendFree => _require(
    _llamaBackendFree,
    'llama_backend_free',
  ).asFunction<LlamaBackendFree>();

  /// `struct llama_model_params llama_model_default_params(void)`.
  LlamaModelDefaultParams get llamaModelDefaultParams => _require(
    _llamaModelDefaultParams,
    'llama_model_default_params',
  ).asFunction<LlamaModelDefaultParams>();

  /// `struct llama_model * llama_model_load_from_file(const char *, params)`.
  LlamaModelLoadFromFile get llamaModelLoadFromFile => _require(
    _llamaModelLoadFromFile,
    'llama_model_load_from_file',
  ).asFunction<LlamaModelLoadFromFile>();

  /// `void llama_model_free(struct llama_model *)`.
  LlamaModelFree get llamaModelFree => _require(
    _llamaModelFree,
    'llama_model_free',
  ).asFunction<LlamaModelFree>();

  /// `const struct llama_vocab * llama_model_get_vocab(const llama_model *)`.
  LlamaModelGetVocab get llamaModelGetVocab => _require(
    _llamaModelGetVocab,
    'llama_model_get_vocab',
  ).asFunction<LlamaModelGetVocab>();

  /// `const char * llama_model_chat_template(const struct llama_model *,
  /// const char *name)`.
  LlamaModelChatTemplate get llamaModelChatTemplate => _require(
    _llamaModelChatTemplate,
    'llama_model_chat_template',
  ).asFunction<LlamaModelChatTemplate>();

  /// `int32_t llama_chat_apply_template(...)`.
  LlamaChatApplyTemplate get llamaChatApplyTemplate => _require(
    _llamaChatApplyTemplate,
    'llama_chat_apply_template',
  ).asFunction<LlamaChatApplyTemplate>();

  /// `int32_t llama_vocab_n_tokens(const struct llama_vocab *)`.
  LlamaVocabNTokens get llamaVocabNTokens => _require(
    _llamaVocabNTokens,
    'llama_vocab_n_tokens',
  ).asFunction<LlamaVocabNTokens>();

  /// `bool llama_vocab_is_eog(const struct llama_vocab *, llama_token)`.
  LlamaVocabIsEog get llamaVocabIsEog => _require(
    _llamaVocabIsEog,
    'llama_vocab_is_eog',
  ).asFunction<LlamaVocabIsEog>();

  /// `llama_token llama_vocab_eos(const struct llama_vocab *)`.
  LlamaVocabEos get llamaVocabEos =>
      _require(_llamaVocabEos, 'llama_vocab_eos').asFunction<LlamaVocabEos>();

  /// `struct llama_context_params llama_context_default_params(void)`.
  LlamaContextDefaultParams get llamaContextDefaultParams => _require(
    _llamaContextDefaultParams,
    'llama_context_default_params',
  ).asFunction<LlamaContextDefaultParams>();

  /// `struct llama_context * llama_init_from_model(model, params)`.
  LlamaInitFromModel get llamaInitFromModel => _require(
    _llamaInitFromModel,
    'llama_init_from_model',
  ).asFunction<LlamaInitFromModel>();

  /// `void llama_free(struct llama_context *)`.
  LlamaFree get llamaFree =>
      _require(_llamaFree, 'llama_free').asFunction<LlamaFree>();

  /// `uint32_t llama_n_ctx(const struct llama_context *)`.
  LlamaNCtx get llamaNCtx =>
      _require(_llamaNCtx, 'llama_n_ctx').asFunction<LlamaNCtx>();

  /// `uint32_t llama_n_batch(const struct llama_context *)`.
  LlamaNBatch get llamaNBatch =>
      _require(_llamaNBatch, 'llama_n_batch').asFunction<LlamaNBatch>();

  /// `int32_t llama_tokenize(...)`.
  LlamaTokenize get llamaTokenize =>
      _require(_llamaTokenize, 'llama_tokenize').asFunction<LlamaTokenize>();

  /// `int32_t llama_token_to_piece(...)`.
  LlamaTokenToPiece get llamaTokenToPiece => _require(
    _llamaTokenToPiece,
    'llama_token_to_piece',
  ).asFunction<LlamaTokenToPiece>();

  /// `struct llama_batch llama_batch_init(int32_t, int32_t, int32_t)`.
  LlamaBatchInit get llamaBatchInit => _require(
    _llamaBatchInit,
    'llama_batch_init',
  ).asFunction<LlamaBatchInit>();

  /// `void llama_batch_free(struct llama_batch)`.
  LlamaBatchFree get llamaBatchFree => _require(
    _llamaBatchFree,
    'llama_batch_free',
  ).asFunction<LlamaBatchFree>();

  /// `int32_t llama_decode(struct llama_context *, struct llama_batch)`.
  LlamaDecode get llamaDecode =>
      _require(_llamaDecode, 'llama_decode').asFunction<LlamaDecode>();

  /// `llama_memory_t llama_get_memory(const struct llama_context *)`.
  LlamaGetMemory get llamaGetMemory => _require(
    _llamaGetMemory,
    'llama_get_memory',
  ).asFunction<LlamaGetMemory>();

  /// `void llama_memory_clear(llama_memory_t mem, bool data)`.
  LlamaMemoryClear get llamaMemoryClear => _require(
    _llamaMemoryClear,
    'llama_memory_clear',
  ).asFunction<LlamaMemoryClear>();

  /// `struct llama_sampler * llama_sampler_chain_init(params)`.
  LlamaSamplerChainInit get llamaSamplerChainInit => _require(
    _llamaSamplerChainInit,
    'llama_sampler_chain_init',
  ).asFunction<LlamaSamplerChainInit>();

  /// `void llama_sampler_chain_add(chain, smpl)`.
  LlamaSamplerChainAdd get llamaSamplerChainAdd => _require(
    _llamaSamplerChainAdd,
    'llama_sampler_chain_add',
  ).asFunction<LlamaSamplerChainAdd>();

  /// `struct llama_sampler * llama_sampler_init_top_k(int32_t k)`.
  LlamaSamplerInitTopK get llamaSamplerInitTopK => _require(
    _llamaSamplerInitTopK,
    'llama_sampler_init_top_k',
  ).asFunction<LlamaSamplerInitTopK>();

  /// `struct llama_sampler * llama_sampler_init_top_p(float p, size_t)`.
  LlamaSamplerInitTopP get llamaSamplerInitTopP => _require(
    _llamaSamplerInitTopP,
    'llama_sampler_init_top_p',
  ).asFunction<LlamaSamplerInitTopP>();

  /// `struct llama_sampler * llama_sampler_init_min_p(float p, size_t)`.
  LlamaSamplerInitMinP get llamaSamplerInitMinP => _require(
    _llamaSamplerInitMinP,
    'llama_sampler_init_min_p',
  ).asFunction<LlamaSamplerInitMinP>();

  /// `struct llama_sampler * llama_sampler_init_temp(float t)`.
  LlamaSamplerInitTemp get llamaSamplerInitTemp => _require(
    _llamaSamplerInitTemp,
    'llama_sampler_init_temp',
  ).asFunction<LlamaSamplerInitTemp>();

  /// `struct llama_sampler * llama_sampler_init_dist(uint32_t seed)`.
  LlamaSamplerInitDist get llamaSamplerInitDist => _require(
    _llamaSamplerInitDist,
    'llama_sampler_init_dist',
  ).asFunction<LlamaSamplerInitDist>();

  /// `llama_token llama_sampler_sample(smpl, ctx, int32_t idx)`.
  LlamaSamplerSample get llamaSamplerSample => _require(
    _llamaSamplerSample,
    'llama_sampler_sample',
  ).asFunction<LlamaSamplerSample>();

  /// `void llama_sampler_free(struct llama_sampler *)`.
  LlamaSamplerFree get llamaSamplerFree => _require(
    _llamaSamplerFree,
    'llama_sampler_free',
  ).asFunction<LlamaSamplerFree>();

  /// `struct llama_perf_context_data llama_perf_context(const llama_context *)`.
  LlamaPerfContext get llamaPerfContext => _require(
    _llamaPerfContext,
    'llama_perf_context',
  ).asFunction<LlamaPerfContext>();

  /// `void llama_perf_context_reset(struct llama_context *)`.
  LlamaPerfContextReset get llamaPerfContextReset => _require(
    _llamaPerfContextReset,
    'llama_perf_context_reset',
  ).asFunction<LlamaPerfContextReset>();

  static ffi.Pointer<ffi.NativeFunction<T>> _require<T extends Function>(
    ffi.Pointer<ffi.NativeFunction<T>>? pointer,
    String symbol,
  ) {
    if (pointer == null) {
      throw StateError(
        'llama.cpp symbol "$symbol" is not bound; call lookupAll() first',
      );
    }
    return pointer;
  }
}
