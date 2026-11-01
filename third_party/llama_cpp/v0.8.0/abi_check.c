// Prints the size and field offsets of the llama.cpp structs that the Dart
// bindings mirror by hand.
//
// Build:
//   clang -std=c11 -I third_party/llama_cpp/v0.8.0/include \
//       third_party/llama_cpp/v0.8.0/abi_check.c -o /tmp/abi_check
//
// Output is line oriented and stable so that
// packages/llama_pulse_core/test/data/inference/native/abi_layout_test.dart can
// parse it:
//
//   size LlamaModelParams 80
//   off LlamaModelParams devices 0
//   width LlamaModelParams devices 8
//   ...
//
// The struct names are the Dart class names; the field names are the C field
// names, in declaration order. Keep this list in sync with the vendored
// llama.h (v0.8.0) whenever the pin moves.

#include <stddef.h>
#include <stdio.h>

#include "llama.h"

#define PRINT_SIZE(type, name) printf("size " #name " %zu\n", sizeof(type))

#define PRINT_OFF(type, name, field) \
    printf("off " #name " " #field " %zu\n", offsetof(type, field))

// `sizeof` does not evaluate its operand, so the null cast is safe. For a
// function-pointer field this prints the pointer width, which is what the Dart
// binding stores.
#define PRINT_WIDTH(type, name, field) \
    printf("width " #name " " #field " %zu\n", sizeof(((type *) 0)->field))

int main(void) {
    // struct llama_model_params -> LlamaModelParams
    PRINT_SIZE(struct llama_model_params, LlamaModelParams);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, devices);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, devices);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, tensor_buft_overrides);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, tensor_buft_overrides);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, n_gpu_layers);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, n_gpu_layers);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, split_mode);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, split_mode);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, load_mode);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, load_mode);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, lazy_mode);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, lazy_mode);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, main_gpu);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, main_gpu);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, tensor_split);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, tensor_split);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, progress_callback);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, progress_callback);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, progress_callback_user_data);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, progress_callback_user_data);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, kv_overrides);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, kv_overrides);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, vocab_only);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, vocab_only);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, check_tensors);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, check_tensors);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, use_extra_bufts);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, use_extra_bufts);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, no_host);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, no_host);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, no_alloc);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, no_alloc);
    PRINT_OFF(struct llama_model_params, LlamaModelParams, load_mtp);
    PRINT_WIDTH(struct llama_model_params, LlamaModelParams, load_mtp);

    // struct llama_context_params -> LlamaContextParams
    PRINT_SIZE(struct llama_context_params, LlamaContextParams);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_ctx);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_ctx);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_batch);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_batch);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_ubatch);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_ubatch);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_seq_max);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_seq_max);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_rs_seq);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_rs_seq);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_outputs_max);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_outputs_max);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_outputs_max_per_seq);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_outputs_max_per_seq);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_threads);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_threads);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_threads_batch);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_threads_batch);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, ctx_type);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, ctx_type);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, rope_scaling_type);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, rope_scaling_type);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, pooling_type);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, pooling_type);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, attention_type);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, attention_type);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, flash_attn_type);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, flash_attn_type);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, rope_freq_base);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, rope_freq_base);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, rope_freq_scale);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, rope_freq_scale);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, yarn_ext_factor);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, yarn_ext_factor);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, yarn_attn_factor);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, yarn_attn_factor);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, yarn_beta_fast);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, yarn_beta_fast);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, yarn_beta_slow);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, yarn_beta_slow);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, yarn_orig_ctx);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, yarn_orig_ctx);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, defrag_thold);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, defrag_thold);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, cb_eval);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, cb_eval);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, cb_eval_user_data);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, cb_eval_user_data);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, type_k);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, type_k);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, type_v);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, type_v);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, moe_cache_size);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, moe_cache_size);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, abort_callback);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, abort_callback);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, abort_callback_data);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, abort_callback_data);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, embeddings);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, embeddings);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, offload_kqv);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, offload_kqv);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, no_perf);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, no_perf);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, op_offload);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, op_offload);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, swa_full);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, swa_full);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, kv_unified);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, kv_unified);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, samplers);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, samplers);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, n_samplers);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, n_samplers);
    PRINT_OFF(struct llama_context_params, LlamaContextParams, ctx_other);
    PRINT_WIDTH(struct llama_context_params, LlamaContextParams, ctx_other);

    // struct llama_batch -> LlamaBatch
    PRINT_SIZE(struct llama_batch, LlamaBatch);
    PRINT_OFF(struct llama_batch, LlamaBatch, n_tokens);
    PRINT_WIDTH(struct llama_batch, LlamaBatch, n_tokens);
    PRINT_OFF(struct llama_batch, LlamaBatch, token);
    PRINT_WIDTH(struct llama_batch, LlamaBatch, token);
    PRINT_OFF(struct llama_batch, LlamaBatch, embd);
    PRINT_WIDTH(struct llama_batch, LlamaBatch, embd);
    PRINT_OFF(struct llama_batch, LlamaBatch, pos);
    PRINT_WIDTH(struct llama_batch, LlamaBatch, pos);
    PRINT_OFF(struct llama_batch, LlamaBatch, n_seq_id);
    PRINT_WIDTH(struct llama_batch, LlamaBatch, n_seq_id);
    PRINT_OFF(struct llama_batch, LlamaBatch, seq_id);
    PRINT_WIDTH(struct llama_batch, LlamaBatch, seq_id);
    PRINT_OFF(struct llama_batch, LlamaBatch, logits);
    PRINT_WIDTH(struct llama_batch, LlamaBatch, logits);

    // struct llama_sampler_chain_params -> LlamaSamplerChainParams
    PRINT_SIZE(struct llama_sampler_chain_params, LlamaSamplerChainParams);
    PRINT_OFF(struct llama_sampler_chain_params, LlamaSamplerChainParams, no_perf);
    PRINT_WIDTH(struct llama_sampler_chain_params, LlamaSamplerChainParams, no_perf);

    // struct llama_perf_context_data -> LlamaPerfContextData
    PRINT_SIZE(struct llama_perf_context_data, LlamaPerfContextData);
    PRINT_OFF(struct llama_perf_context_data, LlamaPerfContextData, t_start_ms);
    PRINT_WIDTH(struct llama_perf_context_data, LlamaPerfContextData, t_start_ms);
    PRINT_OFF(struct llama_perf_context_data, LlamaPerfContextData, t_load_ms);
    PRINT_WIDTH(struct llama_perf_context_data, LlamaPerfContextData, t_load_ms);
    PRINT_OFF(struct llama_perf_context_data, LlamaPerfContextData, t_p_eval_ms);
    PRINT_WIDTH(struct llama_perf_context_data, LlamaPerfContextData, t_p_eval_ms);
    PRINT_OFF(struct llama_perf_context_data, LlamaPerfContextData, t_eval_ms);
    PRINT_WIDTH(struct llama_perf_context_data, LlamaPerfContextData, t_eval_ms);
    PRINT_OFF(struct llama_perf_context_data, LlamaPerfContextData, n_p_eval);
    PRINT_WIDTH(struct llama_perf_context_data, LlamaPerfContextData, n_p_eval);
    PRINT_OFF(struct llama_perf_context_data, LlamaPerfContextData, n_eval);
    PRINT_WIDTH(struct llama_perf_context_data, LlamaPerfContextData, n_eval);
    PRINT_OFF(struct llama_perf_context_data, LlamaPerfContextData, n_reused);
    PRINT_WIDTH(struct llama_perf_context_data, LlamaPerfContextData, n_reused);
    PRINT_OFF(struct llama_perf_context_data, LlamaPerfContextData, n_reallocs_same);
    PRINT_WIDTH(struct llama_perf_context_data, LlamaPerfContextData, n_reallocs_same);
    PRINT_OFF(struct llama_perf_context_data, LlamaPerfContextData, n_reallocs_diff);
    PRINT_WIDTH(struct llama_perf_context_data, LlamaPerfContextData, n_reallocs_diff);

    // struct llama_chat_message -> LlamaChatMessage
    PRINT_SIZE(struct llama_chat_message, LlamaChatMessage);
    PRINT_OFF(struct llama_chat_message, LlamaChatMessage, role);
    PRINT_WIDTH(struct llama_chat_message, LlamaChatMessage, role);
    PRINT_OFF(struct llama_chat_message, LlamaChatMessage, content);
    PRINT_WIDTH(struct llama_chat_message, LlamaChatMessage, content);

    return 0;
}
