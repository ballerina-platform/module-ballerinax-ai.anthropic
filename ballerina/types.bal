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

const WEB_SEARCH_TOOL_NAME = "web_search";
const CODE_EXECUTION_TOOL_NAME = "code_execution";
const string DEFAULT_WEB_SEARCH_TOOL_TYPE = "web_search_20250305";
const string DEFAULT_CODE_EXECUTION_TOOL_TYPE = "code_execution_20250825";

# Approximate user location for localizing web search results.
public type UserLocation record {|
    # The city name (e.g., "San Francisco")
    string city?;
    # The region or state (e.g., "California")
    string region?;
    # The ISO country code (e.g., "US")
    string country?;
    # The IANA timezone ID (e.g., "America/Los_Angeles")
    string timezone?;
|};

# Configuration for the Anthropic web search tool.
# Ref: https://platform.claude.com/docs/en/docs/agents-and-tools/tool-use/web-search-tool
public type WebSearchToolConfig record {|
    # The web search tool version. Defaults to "web_search_20250305".
    # Use "web_search_20260209" for dynamic filtering (requires code_execution tool + Opus/Sonnet 4.6).
    string 'type = DEFAULT_WEB_SEARCH_TOOL_TYPE;
    # Maximum number of web searches allowed per request
    int max_uses?;
    # Only include results from these domains (mutually exclusive with blocked_domains)
    string[] allowed_domains?;
    # Never include results from these domains (mutually exclusive with allowed_domains)
    string[] blocked_domains?;
    # Approximate user location for localizing search results
    UserLocation user_location?;
|};

# Web search tool for Anthropic models.
# Gives Claude access to real-time web content with cited sources.
# Ref: https://platform.claude.com/docs/en/docs/agents-and-tools/tool-use/web-search-tool
public type WebSearchTool record {|
    *ai:BuiltInTool;
    # Tool identifier. Always `"web_search"`.
    "web_search" name = "web_search";
    # Web search tool configurations
    WebSearchToolConfig configurations?;
|};

# Configuration for the Anthropic code execution tool.
# Ref: https://platform.claude.com/docs/en/docs/agents-and-tools/tool-use/code-execution-tool
public type CodeExecutionToolConfig record {|
    # The code execution tool version. Defaults to "code_execution_20250825".
    # Versions: "code_execution_20250522" (legacy Python-only),
    #           "code_execution_20250825" (Bash + file ops),
    #           "code_execution_20260120" (REPL state persistence).
    string 'type = DEFAULT_CODE_EXECUTION_TOOL_TYPE;
|};

# Code execution tool for Anthropic models.
# Allows Claude to run code in a sandboxed environment.
# Ref: https://platform.claude.com/docs/en/docs/agents-and-tools/tool-use/code-execution-tool
public type CodeExecutionTool record {|
    *ai:BuiltInTool;
    # Tool identifier. Always `"code_execution"`.
    "code_execution" name = "code_execution";
    # Code execution tool configurations
    CodeExecutionToolConfig configurations?;
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

# Content block in Anthropic API response
type ContentBlock record {
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
