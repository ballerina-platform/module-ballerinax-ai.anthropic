// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/ai;
import ballerina/http;

# Configurations for controlling the behaviours when communicating with a remote HTTP endpoint.
@display {label: "Connection Configuration"}
public type ConnectionConfig record {|

    # The HTTP version understood by the client
    @display {label: "HTTP Version"}
    http:HttpVersion httpVersion = http:HTTP_2_0;

    # Configurations related to HTTP/1.x protocol
    @display {label: "HTTP1 Settings"}
    http:ClientHttp1Settings http1Settings?;

    # Configurations related to HTTP/2 protocol
    @display {label: "HTTP2 Settings"}
    http:ClientHttp2Settings http2Settings?;

    # The maximum time to wait (in seconds) for a response before closing the connection
    @display {label: "Timeout"}
    decimal timeout = 60;

    # The choice of setting `forwarded`/`x-forwarded` header
    @display {label: "Forwarded"}
    string forwarded = "disable";

    # Configurations associated with request pooling
    @display {label: "Pool Configuration"}
    http:PoolConfiguration poolConfig?;

    # HTTP caching related configurations
    @display {label: "Cache Configuration"}
    http:CacheConfig cache?;

    # Specifies the way of handling compression (`accept-encoding`) header
    @display {label: "Compression"}
    http:Compression compression = http:COMPRESSION_AUTO;

    # Configurations associated with the behaviour of the Circuit Breaker
    @display {label: "Circuit Breaker Configuration"}
    http:CircuitBreakerConfig circuitBreaker?;

    # Configurations associated with retrying
    @display {label: "Retry Configuration"}
    http:RetryConfig retryConfig?;

    # Configurations associated with inbound response size limits
    @display {label: "Response Limit Configuration"}
    http:ResponseLimitConfigs responseLimits?;

    # SSL/TLS-related options
    @display {label: "Secure Socket Configuration"}
    http:ClientSecureSocket secureSocket?;

    # Proxy server related options
    @display {label: "Proxy Configuration"}
    http:ProxyConfig proxy?;

    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    @display {label: "Payload Validation"}
    boolean validation = true;
|};

# Models types for Anthropic
@display {label: "Anthropic Model Names"}
public enum ANTHROPIC_MODEL_NAMES {
    CLAUDE_SONNET_4_5 = "claude-sonnet-4-5",
    CLAUDE_SONNET_4_5_20250929 = "claude-sonnet-4-5-20250929",
    CLAUDE_HAIKU_4_5 = "claude-haiku-4-5",
    CLAUDE_HAIKU_4_5_20251001 = "claude-haiku-4-5-20251001",
    CLAUDE_OPUS_4_5 = "claude-opus-4-5",
    CLAUDE_OPUS_4_5_20251101 = "claude-opus-4-5-20251101",
    CLAUDE_OPUS_4_6 = "claude-opus-4-6",
    CLAUDE_SONNET_4_6 = "claude-sonnet-4-6",
    CLAUDE_OPUS_4_1_20250805 = "claude-opus-4-1-20250805",
    CLAUDE_OPUS_4_20250514 = "claude-opus-4-20250514",
    CLAUDE_SONNET_4_20250514 = "claude-sonnet-4-20250514",
    CLAUDE_3_7_SONNET_20250219 = "claude-3-7-sonnet-20250219",
    CLAUDE_3_5_HAIKU_20241022 = "claude-3-5-haiku-20241022",
    CLAUDE_3_5_SONNET_20241022 = "claude-3-5-sonnet-20241022",
    CLAUDE_3_5_SONNET_20240620 = "claude-3-5-sonnet-20240620",
    CLAUDE_3_OPUS_20240229 = "claude-3-opus-20240229",
    CLAUDE_3_SONNET_20240229 = "claude-3-sonnet-20240229",
    CLAUDE_3_HAIKU_20240307 = "claude-3-haiku-20240307"
}

# Extended thinking (reasoning) configuration for Anthropic models. Exactly one of the
# three variants is chosen; the `type` field discriminates them.
#
# Only Claude 3.7 Sonnet and Claude 4.x models support extended thinking. When thinking is
# `enabled` or `adaptive`, Anthropic requires the default temperature, so the provider
# omits `temperature` from the request in those cases.
@display {label: "Thinking Configuration"}
public type ThinkingConfig EnabledThinking|AdaptiveThinking|DisabledThinking;

# Enables extended thinking with a fixed token budget.
public type EnabledThinking record {|
    # Discriminator; always "enabled"
    "enabled" 'type = "enabled";
    # Maximum number of tokens the model may spend on internal thinking. Must be at least
    # 1024 and strictly less than the request's `maxTokens`.
    int budget_tokens;
|};

# Enables adaptive extended thinking, letting the model decide how much to think.
public type AdaptiveThinking record {|
    # Discriminator; always "adaptive"
    "adaptive" 'type = "adaptive";
    # How the thinking is returned: "summarized" (a condensed summary of the reasoning) or
    # "omitted" (the reasoning is not returned). When absent, the API default applies.
    "summarized"|"omitted" display?;
|};

# Explicitly disables extended thinking (the default behaviour when no config is given).
public type DisabledThinking record {|
    # Discriminator; always "disabled"
    "disabled" 'type = "disabled";
|};

# Anthropic API request message format
type AnthropicMessage record {|
    # Role of the participant in the conversation (e.g., "user" or "assistant")
    string role;
    # The message content
    string content;
|};

# Anthropic API response format
type AnthropicApiResponse record {
    # Unique identifier for the response message
    string id;
    # The Anthropic model used for generating the response
    string model;
    # The type of the response (e.g., "message")
    string 'type;
    # Array of content blocks containing the response text and media
    ContentBlock[] content;
    # Role of the message sender (typically "assistant")
    string role;
    # Reason why the generation stopped (e.g., "end_turn", "max_tokens")
    string stop_reason;
    # The sequence that caused generation to stop, if applicable
    string? stop_sequence;
    # Token usage statistics for the request and response
    Usage usage;
};

# Information about what invoked a tool (the model directly or a server-side tool)
type ToolCaller record {
    # Caller type ("direct", "code_execution_20250825", "code_execution_20260120")
    string 'type;
    # Identifier of the server-side tool that invoked this tool, if applicable
    string? tool_id = ();
};

# Content block in Anthropic API response
#
# A single open record covering every content block type returned in the response
# `content` array, discriminated by the `type` field. Each field below is populated
# only for the block type(s) noted.
type ContentBlock record {
    # The type of content. One of: "text", "thinking", "redacted_thinking",
    # "tool_use", "server_tool_use", "web_search_tool_result",
    # "web_fetch_tool_result", "code_execution_tool_result",
    # "bash_code_execution_tool_result", "text_editor_code_execution_tool_result",
    # "tool_search_tool_result", "container_upload"
    string 'type;
    # The actual text content (for text type)
    string text?;
    # Citations supporting the text block (for text type)
    json citations?;
    # Internal reasoning text produced by the model (for thinking type)
    string thinking?;
    # Signature verifying the thinking block integrity (for thinking type)
    string signature?;
    # Opaque data for a redacted thinking block (for redacted_thinking type)
    string data?;
    # Unique identifier for tool_use and server_tool_use blocks
    string id?;
    # Name of the tool being used (for tool_use and server_tool_use types)
    string name?;
    # Input parameters for the tool (for tool_use and server_tool_use types)
    json input?;
    # Information about what invoked the tool (for tool_use, server_tool_use,
    # and tool result types)
    ToolCaller caller?;
    # Identifier of the tool_use block this result corresponds to (for all
    # *_tool_result types)
    string tool_use_id?;
    # The result payload of a server-side tool call (for all *_tool_result types)
    json content?;
    # Identifier of a file uploaded to the container (for container_upload type)
    string file_id?;
};

# Breakdown of cached tokens by TTL bucket.
#
# Every field is optional: these are wire-format records, and Anthropic may omit a
# bucket or add new ones. A required field here would fail the conversion of the whole
# enclosing response/event, so absence is modelled rather than rejected.
type CacheCreation record {
    # Number of input tokens used to create the 1 hour cache entry, if reported
    int? ephemeral_1h_input_tokens = ();
    # Number of input tokens used to create the 5 minute cache entry, if reported
    int? ephemeral_5m_input_tokens = ();
};

# Breakdown of output tokens by category
type OutputTokensDetails record {
    # Number of output tokens spent on internal reasoning, if reported
    int? thinking_tokens = ();
};

# Number of server-side tool requests made during the response
type ServerToolUsage record {
    # Number of web fetch tool requests, if any were made
    int? web_fetch_requests = ();
    # Number of web search tool requests, if any were made
    int? web_search_requests = ();
};

# Usage statistics in Anthropic API response
type Usage record {
    # Number of tokens in the input messages
    int input_tokens;
    # Number of tokens in the generated response
    int output_tokens;
    # Number of input tokens used for cache creation, if applicable
    int? cache_creation_input_tokens = ();
    # Number of input tokens read from cache, if applicable
    int? cache_read_input_tokens = ();
    # Breakdown of cached tokens by TTL bucket, if applicable
    CacheCreation? cache_creation = ();
    # Geographic region where inference was performed, if applicable
    string? inference_geo = ();
    # Breakdown of output tokens by category, if applicable
    OutputTokensDetails? output_tokens_details = ();
    # Number of server tool requests made during the response, if applicable
    ServerToolUsage? server_tool_use = ();
    # Service tier used for this request (e.g., "standard", "priority", "batch")
    string? service_tier = ();
};

# Anthropic Tool definition
type AnthropicTool record {|
    # Name of the tool
    string name;
    # Description of the tool
    string description;
    # Input schema of the tool in JSON Schema format
    json input_schema;
|};

# Streaming event that initiates the stream with message metadata and input token usage
type StreamMessageStart record {
    # Event type ("message_start")
    string 'type;
    # The initial message object containing metadata and token usage
    StreamMessageStartMessage message;
};

# Container used for code execution tool requests
type MessageContainer record {
    # Unique identifier for the container, if reported
    string? id = ();
    # Expiry timestamp of the container (ISO 8601), if reported
    string? expires_at = ();
};

# Structured information about a model refusal
type RefusalStopDetails record {
    # Event type, always "refusal"
    string 'type;
    # Policy category that triggered the refusal (e.g., "cyber", "bio")
    string? category = ();
    # Human-readable explanation of the refusal, if available
    string? explanation = ();
};

# Message metadata delivered in the message_start streaming event
type StreamMessageStartMessage record {
    # Unique identifier for the message
    string id;
    # Type of the object (always "message")
    string 'type;
    # Role of the message sender (always "assistant")
    string role;
    # The Anthropic model used for generating the response
    string model;
    # Content blocks generated so far, empty array at stream start
    ContentBlock[] content;
    # Reason why generation stopped, null at stream start
    string? stop_reason = ();
    # The sequence that caused generation to stop, null at stream start
    string? stop_sequence = ();
    # Structured refusal details, null unless stop_reason is "refusal"
    RefusalStopDetails? stop_details = ();
    # Container used for code execution requests, if applicable
    MessageContainer? container = ();
    # Token usage statistics at the start of the stream
    Usage usage;
};

# Streaming event marking the beginning of a new content block
type StreamContentBlockStart record {
    # Event type ("content_block_start")
    string 'type;
    # Index of the content block
    int index;
    # The starting content block, in its initial (empty) form. This is the same
    # shape as a response `ContentBlock`; fields like `input`, `text`, and
    # `thinking` start empty and are filled in by subsequent content_block_delta
    # events. Server-side tool results (e.g. web_search_tool_result) arrive here
    # fully populated.
    ContentBlock content_block;
};

# Delta content in a streaming response
#
# A single open record covering every delta variant in a content_block_delta
# event, discriminated by the `type` field. Each field below is populated only
# for the delta type noted.
type StreamDelta record {
    # Type of delta. One of: "text_delta", "input_json_delta", "thinking_delta",
    # "signature_delta", "citations_delta"
    string 'type;
    # Text content chunk (for text_delta type)
    string text?;
    # Partial JSON string chunk of tool input (for input_json_delta type)
    string partial_json?;
    # Reasoning text chunk (for thinking_delta type)
    string thinking?;
    # Signature verifying the thinking block, sent just before content_block_stop
    # (for signature_delta type)
    string signature?;
    # A single citation appended to the text block (for citations_delta type)
    json citation?;
};

# Streaming event that delivers an incremental chunk of content
type StreamContentBlockDelta record {
    # Event type ("content_block_delta")
    string 'type;
    # Index of the content block being updated
    int index;
    # The incremental delta content
    StreamDelta delta;
};

# Streaming event marking the end of a content block
type StreamContentBlockStop record {
    # Event type ("content_block_stop")
    string 'type;
    # Index of the content block that has ended
    int index;
};

# Top-level delta in the message_delta event carrying final message changes
type StreamMessageDeltaData record {
    # Reason why generation stopped (e.g., "end_turn", "tool_use", "refusal")
    string? stop_reason = ();
    # The sequence that caused generation to stop, if applicable
    string? stop_sequence = ();
    # Container used for code execution requests, if applicable
    MessageContainer? container = ();
    # Structured refusal details, set when stop_reason is "refusal"
    RefusalStopDetails? stop_details = ();
};

# Cumulative billing and rate-limit usage reported in the message_delta event.
# This is a subset of the full response `Usage` (no cache_creation breakdown,
# inference_geo, or output_tokens_details).
type MessageDeltaUsage record {
    # Cumulative number of output tokens generated
    int output_tokens;
    # Number of input tokens used, if reported
    int? input_tokens = ();
    # Number of input tokens used for cache creation, if applicable
    int? cache_creation_input_tokens = ();
    # Number of input tokens read from cache, if applicable
    int? cache_read_input_tokens = ();
    # Number of server tool requests made during the response, if applicable
    ServerToolUsage? server_tool_use = ();
    # Service tier used for this request (e.g., "standard", "priority", "batch")
    string? service_tier = ();
};

# Streaming event carrying top-level message changes and cumulative token usage
type StreamMessageDelta record {
    # Event type ("message_delta")
    string 'type;
    # Top-level changes to the final message (stop reason, refusal, container)
    StreamMessageDeltaData delta;
    # Cumulative token usage at the end of the stream
    MessageDeltaUsage usage;
};

# Streaming event that terminates the stream; no further events will follow
type StreamMessageStop record {
    # Event type ("message_stop")
    string 'type;
};

# Body of an `error` streaming event.
#
# Anthropic can fail a request *after* the stream has opened and some content has already
# been delivered (for example `overloaded_error` during generation). The transport still
# reports success, so this event is the only signal that the response is incomplete.
type StreamErrorDetail record {
    # Error category (e.g. "overloaded_error", "api_error", "invalid_request_error")
    string? 'type = ();
    # Human-readable description of the failure
    string? message = ();
};

# Streaming event signalling that generation failed mid-stream
type StreamError record {
    # Event type ("error")
    string 'type;
    # The error reported by the API
    StreamErrorDetail? 'error = ();
};

# Periodic keepalive event sent by the server to maintain the connection
type StreamPing record {
    # Event type ("ping")
    string 'type;
};

# Maps a single Anthropic streaming SSE event onto a normalized `ai:ChatCompletionChunk`.
#
# Anthropic's stream is stateful: the message id/model and input-token count arrive once
# on `message_start`, tool ids/names arrive on `content_block_start`, and the argument
# fragments arrive on subsequent `content_block_delta` events keyed by the content-block
# `index`. The caller (the iterator) carries that state and passes it in here. Events that
# do not produce a chunk (`ping`, `content_block_stop`) yield `()`; malformed payloads
# yield an `error` so the caller can skip them.
#
# + event - The SSE event type (e.g. "message_start", "content_block_delta")
# + data - The raw JSON payload of the event
# + id - The message id captured from `message_start`
# + model - The model name captured from `message_start`
# + inputTokens - The prompt token count captured from `message_start`
# + return - The mapped chunk, `()` for non-emitting events, or an error on a malformed payload
isolated function toAiChunk(string event, json data, string? id, string? model, int? inputTokens)
        returns ai:ChatCompletionChunk?|error {
    match event {
        "message_start" => {
            ai:ChatCompletionChunkDelta delta = {};
            ai:ROLE? role = mapRole("assistant");
            if role is ai:ROLE {
                delta.role = role;
            }
            return buildChunk(id, model, [{index: 0, delta}]);
        }
        "content_block_start" => {
            StreamContentBlockStart blockStart = check data.cloneWithType();
            ContentBlock block = blockStart.content_block;
            if block.'type != "tool_use" {
                return ();
            }
            ai:ToolCallChunk toolCall = {index: blockStart.index};
            string? toolId = block.id;
            if toolId is string {
                toolCall.id = toolId;
            }
            ai:FunctionCallChunk fragment = {};
            string? name = block.name;
            if name is string {
                fragment.name = name;
            }
            toolCall.'function = fragment;
            ai:ChatCompletionChunkDelta delta = {toolCalls: [toolCall]};
            return buildChunk(id, model, [{index: 0, delta}]);
        }
        "content_block_delta" => {
            StreamContentBlockDelta blockDelta = check data.cloneWithType();
            StreamDelta streamDelta = blockDelta.delta;
            match streamDelta.'type {
                "text_delta" => {
                    ai:ChatCompletionChunkDelta delta = {content: streamDelta.text};
                    return buildChunk(id, model, [{index: 0, delta}]);
                }
                "thinking_delta" => {
                    ai:ChatCompletionChunkDelta delta = {reasoning: streamDelta.thinking};
                    return buildChunk(id, model, [{index: 0, delta}]);
                }
                "input_json_delta" => {
                    ai:ToolCallChunk toolCall = {
                        index: blockDelta.index,
                        'function: {arguments: streamDelta.partial_json ?: ""}
                    };
                    ai:ChatCompletionChunkDelta delta = {toolCalls: [toolCall]};
                    return buildChunk(id, model, [{index: 0, delta}]);
                }
            }
            return ();
        }
        "message_delta" => {
            StreamMessageDelta messageDelta = check data.cloneWithType();
            ai:ChatCompletionChunkDelta delta = {};
            ai:FinishReason? finishReason = mapFinishReason(messageDelta.delta.stop_reason);
            ai:ChatCompletionChunk chunk = buildChunk(id, model, [{index: 0, delta, finishReason}]);
            int outputTokens = messageDelta.usage.output_tokens;
            ai:CompletionTokenUsage usage = {completionTokens: outputTokens};
            if inputTokens is int {
                usage.promptTokens = inputTokens;
                usage.totalTokens = inputTokens + outputTokens;
            }
            chunk.usage = usage;
            return chunk;
        }
    }
    return ();
}

# Builds an `ai:ChatCompletionChunk`, stamping the carried message id/model when present.
#
# + id - The message id, if known
# + model - The model name, if known
# + choices - The choices for this chunk
# + return - The assembled chunk
isolated function buildChunk(string? id, string? model, ai:ChatCompletionChunkChoice[] choices)
        returns ai:ChatCompletionChunk {
    ai:ChatCompletionChunk chunk = {choices};
    if id is string {
        chunk.id = id;
    }
    if model is string {
        chunk.model = model;
    }
    return chunk;
}

# Safely maps an Anthropic role string onto the `ai:ROLE` enum; returns `()` for absent or
# unrecognized values rather than panicking on a cast. Streamed deltas only carry the
# "assistant" role; the others are handled for completeness. ("function" is request-only
# and its `ai` enum member is not accessible here, so it is intentionally omitted.)
#
# + role - The role string
# + return - The mapped `ai:ROLE`, or `()` when absent/unrecognized
isolated function mapRole(string? role) returns ai:ROLE? {
    match role {
        "system" => {
            return ai:SYSTEM;
        }
        "user" => {
            return ai:USER;
        }
        "assistant" => {
            return ai:ASSISTANT;
        }
    }
    return ();
}

# Safely maps an Anthropic `stop_reason` onto the `ai:FinishReason` enum. The `ai` enum is
# the OpenAI set, so Anthropic-specific reasons are folded: `stop_sequence` joins `end_turn`
# as `stop`, `model_context_window_exceeded` joins `max_tokens` as `length`, and `refusal`
# maps to `content_filter`. Returns `()` for absent or unrecognized values (e.g. `pause_turn`).
#
# + stopReason - The stop reason from the wire `message_delta`
# + return - The mapped `ai:FinishReason`, or `()` when absent/unrecognized
isolated function mapFinishReason(string? stopReason) returns ai:FinishReason? {
    match stopReason {
        "end_turn"|"stop_sequence" => {
            return ai:STOP;
        }
        "max_tokens"|"model_context_window_exceeded" => {
            return ai:LENGTH;
        }
        "tool_use" => {
            return ai:TOOL_CALLS;
        }
        "refusal" => {
            return ai:CONTENT_FILTER;
        }
    }
    return ();
}

