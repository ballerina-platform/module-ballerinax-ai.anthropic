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

# Content block in Anthropic API response
type ContentBlock record {|
    # The type of content (e.g., "text" or "tool_use")
    string 'type;
    # The actual text content (for text type)
    string text?;
    # Tool use information (for tool_use type)
    string id?;
    # Name of the tool being used
    string name?;
    # Input parameters for the tool
    json input?;
|};

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
