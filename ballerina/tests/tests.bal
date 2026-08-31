// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 Inc. licenses this file to you under the Apache License,
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
import ballerina/test;

const SERVICE_URL = "http://localhost:8080/llm/anthropic";
const STREAM_TEST_SERVICE_URL = "http://localhost:9090/streamtest/anthropic";
const API_KEY = "not-a-real-api-key";
const ERROR_MESSAGE = "Error occurred while attempting to parse the response from the LLM as the expected type. Retrying and/or validating the prompt could fix the response.";
const RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE = "Runtime schema generation is not yet supported";

const STREAM_EDGE_SERVICE_URL = "http://localhost:9092/streamedge";

final ModelProvider claudeProvider = check new (API_KEY, CLAUDE_3_7_SONNET_20250219, SERVICE_URL);
final ModelProvider streamProvider = check new (API_KEY, CLAUDE_3_7_SONNET_20250219, STREAM_TEST_SERVICE_URL);
final ModelProvider errorEventProvider =
    check new (API_KEY, CLAUDE_SONNET_4_5, STREAM_EDGE_SERVICE_URL + "/errorevent");
final ModelProvider truncatedProvider =
    check new (API_KEY, CLAUDE_SONNET_4_5, STREAM_EDGE_SERVICE_URL + "/truncated");
final ModelProvider malformedProvider =
    check new (API_KEY, CLAUDE_SONNET_4_5, STREAM_EDGE_SERVICE_URL + "/malformed");
final ModelProvider partialUsageProvider =
    check new (API_KEY, CLAUDE_SONNET_4_5, STREAM_EDGE_SERVICE_URL + "/partialusage");

const CONFIG_TEST_SERVICE_URL = "http://localhost:9093/configtest";

// A thinking budget needs headroom under `maxTokens`, so this provider raises it above the
// 512 default.
final ModelProvider thinkingProvider = check new (API_KEY, CLAUDE_SONNET_4_5,
        CONFIG_TEST_SERVICE_URL + "/plain", maxTokens = 4096,
        thinkingConfig = <EnabledThinking>{budget_tokens: 2048});
final ModelProvider thinkingStreamProvider = check new (API_KEY, CLAUDE_SONNET_4_5,
        CONFIG_TEST_SERVICE_URL + "/stream", maxTokens = 4096,
        thinkingConfig = <AdaptiveThinking>{});

@test:Config
function testGenerateMethodWithBasicReturnType() returns ai:Error? {
    int|error rating = claudeProvider->generate(`Rate this blog out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, 4);
}

@test:Config
function testGenerateMethodWithBasicArrayReturnType() returns ai:Error? {
    int[]|error rating = claudeProvider->generate(`Evaluate this blogs out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}

        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, [9, 1]);
}

@test:Config
function testGenerateMethodWithRecordReturnType() returns error? {
    Review|error result = claudeProvider->generate(`Please rate this blog out of ${"10"}.
        Title: ${blog2.title}
        Content: ${blog2.content}`);
    test:assertEquals(result, check reviewStr.fromJsonStringWithType(Review));
}

@test:Config
function testGenerateMethodWithTextDocument() returns ai:Error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    int maxScore = 10;

    int|error rating = claudeProvider->generate(`How would you rate this ${"blog"} content out of ${maxScore}. ${blog}.`);
    test:assertEquals(rating, 4);
}

type ReviewArray Review[];

@test:Config
function testGenerateMethodWithTextDocumentArray() returns error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    ai:TextDocument[] blogs = [blog, blog];
    int maxScore = 10;
    Review r = check reviewStr.fromJsonStringWithType(Review);

    ReviewArray|error result = claudeProvider->generate(`How would you rate these text blogs out of ${maxScore}. ${blogs}. Thank you!`);
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithImageDocumentWithBinaryData() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData
    };

    ai:ImageDocument img2 = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };

    string|error description = claudeProvider->generate(`Describe the following image. ${img}.`);
    test:assertTrue(description is error);
    test:assertTrue((<error>description).message().includes("Please specify the mimeType for the image document."));

    description = claudeProvider->generate(`Describe the following image. ${img2}.`);
    test:assertEquals(description, "This is a sample image description.");
}

@test:Config
function testGenerateMethodWithImageDocumentWithUrl() returns ai:Error? {
    ai:ImageDocument img = {
        content: "https://example.com/image.jpg",
        metadata: {
            mimeType: "image/jpg"
        }
    };

    string|error description = claudeProvider->generate(`Describe the image. ${img}.`);
    test:assertEquals(description, "This is a sample image description.");
}

@test:Config
function testFileDocument() returns ai:Error? {
    ai:FileDocument pdf = {
        metadata: {
            mimeType: "application/pdf"
        },
        content: sampleBinaryData
    };

    ai:FileDocument pdf2 = {
        content: sampleBinaryData
    };

    ai:FileDocument pdf3 = {
        content: "https://sampleurl.com"
    };

    ai:FileDocument pdf4 = {
        content: "<invalid-url>"
    };

    ai:FileDocument pdf5 = {
        content: {fileId: "<file-id>"}
    };

    string|error description = claudeProvider->generate(`Describe the following pdf content. ${pdf}.`);
    test:assertEquals(description, "This is a sample pdf description.");

    string[]|error descriptions = claudeProvider->generate(`Describe the following pdf files. ${<ai:FileDocument[]>[pdf, pdf3]}.`);
    test:assertEquals(descriptions, ["This is a sample pdf description.", "This is a sample pdf description."]);

    description = claudeProvider->generate(`Describe the following pdf file. ${pdf5}.`);
    test:assertEquals(description, "This is a sample pdf description.");

    description = claudeProvider->generate(`Describe the following pdf file. ${pdf2}.`);
    if description is string {
        test:assertFail("Expected an error for missing mimeType in the file document.");
    }
    test:assertEquals(description.message(), "Please specify the mimeType for the file document.");

    description = claudeProvider->generate(`Describe the following pdf file. ${pdf4}.`);
    if description is string {
        test:assertFail("Expected an error for invalid URL in the file document.");
    }
    test:assertEquals(description.message(), "Must be a valid URL.");
}

@test:Config
function testUnsupportedAudioDocument() returns ai:Error? {
    ai:AudioDocument audioDoc = {
        content: sampleBinaryData
    };

    string|ai:Error description = claudeProvider->generate(`Describe the following audio file. ${audioDoc}.`);
    if description is string {
        test:assertFail("Expected an error for unsupported document in the file document.");
    }
    test:assertEquals(description.message(), "Only text, image and file documents are supported.");
}

@test:Config
function testGenerateMethodWithImageDocumentWithInvalidUrl() returns ai:Error? {
    ai:ImageDocument img = {
        content: "This-is-not-a-valid-url"
    };

    string|ai:Error description = claudeProvider->generate(`Please describe the image. ${img}.`);
    test:assertTrue(description is ai:Error);

    string actualErrorMessage = (<ai:Error>description).message();
    string expectedErrorMessage = "Must be a valid URL";
    test:assertTrue((<ai:Error>description).message().includes("Must be a valid URL"),
            string `expected '${expectedErrorMessage}', found ${actualErrorMessage}`);
}

@test:Config
function testGenerateMethodWithImageDocumentArray() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:ImageDocument img2 = {
        content: "https://example.com/image.jpg"
    };

    string[]|error descriptions = claudeProvider->generate(
        `Describe the following ${"2"} images. ${<ai:ImageDocument[]>[img, img2]}.`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample image description."]);
}

@test:Config
function testGenerateMethodWithTextAndImageDocumentArray() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };

    string[]|error descriptions = claudeProvider->generate(
        `Please describe the following image and the doc. ${<ai:Document[]>[img, blog]}.`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample doc description."]);
}

@test:Config
function testGenerateMethodWithImageDocumentsandTextDocuments() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };

    string[]|error descriptions = claudeProvider->generate(
        `${"Describe"} the following ${"text"} ${"document"} and image document. ${img}${blog}`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample doc description."]);
}

@test:Config
function testGenerateMethodWithUnsupportedDocument() returns ai:Error? {
    ai:Document doc = {
        'type: "audio",
        content: "dummy-data"
    };

    string[]|error descriptions = claudeProvider->generate(`What is the content in this document. ${doc}.`);
    test:assertTrue(descriptions is error);
    test:assertTrue((<error>descriptions).message().includes("Only text, image and file documents are supported."));
}

@test:Config
function testGenerateMethodWithRecordArrayReturnType() returns error? {
    int maxScore = 10;
    Review r = check reviewStr.fromJsonStringWithType(Review);

    ReviewArray|error result = claudeProvider->generate(`Please rate this blogs out of ${maxScore}.
        [{Title: ${blog1.title}, Content: ${blog1.content}}, {Title: ${blog2.title}, Content: ${blog2.content}}]`);
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithInvalidBasicType() returns ai:Error? {
    boolean|error rating = claudeProvider->generate(`What is ${1} + ${1}?`);
    test:assertTrue(rating is error);
    test:assertTrue((<error>rating).message().includes(ERROR_MESSAGE));
}

type ProductName record {|
    string name;
|};

@test:Config
function testGenerateMethodWithInvalidRecordType() returns ai:Error? {
    ProductName[]|map<string>|error rating = trap claudeProvider->generate(
                `Tell me name and the age of the top 10 world class cricketers`);
    string msg = (<error>rating).message();
    test:assertTrue(rating is error);
    test:assertTrue(msg.includes(RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE),
        string `expected error message to contain: ${RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE}, but found ${msg}`);
}

type ProductNameArray ProductName[];

@test:Config
function testGenerateMethodWithInvalidRecordArrayType2() returns ai:Error? {
    ProductNameArray|error rating = claudeProvider->generate(
                `Tell me name and the age of the top 10 world class cricketers`);
    test:assertTrue(rating is error);
    test:assertTrue((<error>rating).message().includes(ERROR_MESSAGE));
}

type Cricketers record {|
    string name;
|};

type Cricketers1 record {|
    string name;
|};

type Cricketers2 record {|
    string name;
|};

type Cricketers3 record {|
    string name;
|};

type Cricketers4 record {|
    string name;
|};

type Cricketers5 record {|
    string name;
|};

type Cricketers6 record {|
    string name;
|};

type Cricketers7 record {|
    string name;
|};

type Cricketers8 record {|
    string name;
|};

@test:Config
function testGenerateMethodWithStringUnionNull() returns error? {
    string? result = check claudeProvider->generate(`Give me a random joke`);
    test:assertTrue(result is string);
}

@test:Config
function testGenerateMethodWithRecUnionBasicType() returns error? {
    Cricketers|string result = check claudeProvider->generate(`Give me a random joke about cricketers`);
    test:assertTrue(result is string);
}

@test:Config
function testGenerateMethodWithRecUnionNull() returns error? {
    Cricketers1? result = check claudeProvider->generate(`Name a random world class cricketer in India`);
    test:assertTrue(result is Cricketers1);
}

@test:Config
function testGenerateMethodWithArrayOnly() returns error? {
    Cricketers2[] result = check claudeProvider->generate(`Name 10 world class cricketers in India`);
    test:assertTrue(result is Cricketers2[]);
}

@test:Config
function testGenerateMethodWithArrayUnionBasicType() returns error? {
    Cricketers3[]|string result = check claudeProvider->generate(`Name 10 world class cricketers as string`);
    test:assertTrue(result is Cricketers3[]);
}


@test:Config
function testGenerateMethodWithArrayUnionNull() returns error? {
    Cricketers4[]? result = check claudeProvider->generate(`Name 10 world class cricketers`);
    test:assertTrue(result is Cricketers4[]);
}

@test:Config
function testGenerateMethodWithArrayUnionRecord() returns ai:Error? {
    Cricketers5[]|Cricketers6|error result = claudeProvider->generate(`Name top 10 world class cricketers`);
    test:assertTrue(result is Cricketers5[]);
}

@test:Config
function testGenerateMethodWithArrayUnionRecord2() returns ai:Error? {
   Cricketers7[]|Cricketers8|error result = claudeProvider->generate(`Name a random world class cricketer`);
    test:assertTrue(result is Cricketers8);
}

@test:Config
function testChatStream() returns error? {
    stream<ai:ChatCompletionChunk, ai:Error?>|ai:Error result = streamProvider->chatStream([
        {role: ai:USER, content: "Say hello"}
    ]);
    test:assertFalse(result is ai:Error, "Expected a stream, got an error");
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream = check result;

    string content = "";
    string toolId = "";
    string toolName = "";
    string toolArgs = "";
    ai:FinishReason? finishReason = ();
    ai:CompletionTokenUsage? usage = ();
    check from ai:ChatCompletionChunk chunk in chunkStream
        do {
            if chunk.choices.length() > 0 {
                ai:ChatCompletionChunkChoice choice = chunk.choices[0];
                string? fragment = choice.delta.content;
                if fragment is string {
                    content += fragment;
                }
                ai:ToolCallChunk[]? toolCalls = choice.delta.toolCalls;
                if toolCalls is ai:ToolCallChunk[] {
                    foreach ai:ToolCallChunk toolCall in toolCalls {
                        string? id = toolCall?.id;
                        if id is string {
                            toolId = id;
                        }
                        ai:FunctionCallChunk? 'function = toolCall?.'function;
                        if 'function is ai:FunctionCallChunk {
                            string? name = 'function?.name;
                            if name is string {
                                toolName = name;
                            }
                            string? args = 'function?.arguments;
                            if args is string {
                                toolArgs += args;
                            }
                        }
                    }
                }
                ai:FinishReason? reason = choice.finishReason;
                if reason is ai:FinishReason {
                    finishReason = reason;
                }
            }
            ai:CompletionTokenUsage? chunkUsage = chunk.usage;
            if chunkUsage is ai:CompletionTokenUsage {
                usage = chunkUsage;
            }
        };

    // Text fragments stream and accumulate.
    test:assertEquals(content, "Hello world");
    // Tool id/name arrive on the first fragment; the JSON argument fragments stream and
    // accumulate by index across subsequent chunks.
    test:assertEquals(toolId, "toolu_1");
    test:assertEquals(toolName, "get_weather");
    test:assertEquals(toolArgs, "{\"city\":\"Paris\"}");
    // Anthropic `tool_use` stop reason normalizes to `tool_calls`.
    test:assertEquals(finishReason, ai:TOOL_CALLS);
    // Usage merges message_start input tokens with message_delta output tokens.
    test:assertTrue(usage is ai:CompletionTokenUsage, "Expected usage on the final chunk");
    ai:CompletionTokenUsage finalUsage = check usage.ensureType();
    test:assertEquals(finalUsage.promptTokens, 10);
    test:assertEquals(finalUsage.completionTokens, 7);
    test:assertEquals(finalUsage.totalTokens, 17);
}

@test:Config
function testGenerateStream() returns error? {
    stream<string, ai:Error?>|ai:Error result = streamProvider->generateStream(`Say hello`);
    test:assertFalse(result is ai:Error, "Expected a stream, got an error");
    stream<string, ai:Error?> textStream = check result;

    string collected = "";
    check from string fragment in textStream
        do {
            collected += fragment;
        };
    // generateStream projects each chunk's delta.content; tool-call/usage chunks carry no text.
    test:assertEquals(collected, "Hello world");
}

@test:Config
function testGenerateStreamRejectsNonStringType() returns error? {
    stream<int, ai:Error?>|ai:Error result = streamProvider->generateStream(`Say hello`);
    test:assertTrue(result is ai:Error, "'generateStream' must reject non-string expected types");
}

// `thinkingConfig` must reach every request path. `generate` builds its payload separately
// from `chat`/`chatStream`, so it is the one that previously dropped the setting silently.
@test:Config
function testThinkingConfigAppliesToGenerate() returns error? {
    string _ = check thinkingProvider->generate(`Say hello`);
    map<json> payload = check getCapturedPayload("generate").ensureType();
    test:assertEquals(payload["thinking"], {'type: "enabled", budget_tokens: 2048},
            "'generate' must send the configured thinking block");
    test:assertFalse(payload.hasKey("temperature"),
            "'temperature' must be omitted while extended thinking is active");
}

@test:Config
function testThinkingConfigAppliesToChat() returns error? {
    ai:ChatAssistantMessage _ = check thinkingProvider->chat([{role: ai:USER, content: "Say hello"}]);
    map<json> payload = check getCapturedPayload("chat").ensureType();
    test:assertEquals(payload["thinking"], {'type: "enabled", budget_tokens: 2048},
            "'chat' must send the configured thinking block");
    test:assertFalse(payload.hasKey("temperature"),
            "'temperature' must be omitted while extended thinking is active");
}

@test:Config
function testThinkingConfigAppliesToChatStream() returns error? {
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream =
        check thinkingStreamProvider->chatStream([{role: ai:USER, content: "Say hello"}]);
    check chunkStream.close();
    map<json> payload = check getCapturedPayload("chatStream").ensureType();
    test:assertEquals(payload["thinking"], {'type: "adaptive"},
            "'chatStream' must send the configured thinking block");
    test:assertFalse(payload.hasKey("temperature"),
            "'temperature' must be omitted while extended thinking is active");
}

// Without a thinking config the provider must keep sending `temperature` as before.
@test:Config
function testTemperatureSentWhenThinkingIsOff() returns error? {
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream =
        check streamProvider->chatStream([{role: ai:USER, content: "Say hello"}]);
    check chunkStream.close();
    map<json> payload = check getCapturedPayload("streamtest").ensureType();
    test:assertFalse(payload.hasKey("thinking"), "No thinking block must be sent when unconfigured");
    test:assertEquals(payload["temperature"], 0.7d);
}

// Anthropic requires 1024 <= budget_tokens < max_tokens. Rejecting at construction beats an
// opaque HTTP failure on every later call - especially since the default maxTokens (512) is
// below the minimum budget, making every unvalidated 'enabled' config fail.
@test:Config
function testThinkingBudgetMustBeBelowMaxTokens() returns error? {
    ModelProvider|ai:Error provider = new (API_KEY, CLAUDE_SONNET_4_5, SERVICE_URL,
            maxTokens = 1500, thinkingConfig = <EnabledThinking>{budget_tokens: 2048});
    test:assertTrue(provider is ai:Error, "A budget above 'maxTokens' must be rejected");
    if provider is ai:Error {
        test:assertTrue(provider.message().includes("must be less than 'maxTokens'"),
                "Unexpected message: " + provider.message());
    }
}

@test:Config
function testThinkingBudgetMustMeetMinimum() returns error? {
    ModelProvider|ai:Error provider = new (API_KEY, CLAUDE_SONNET_4_5, SERVICE_URL,
            maxTokens = 4096, thinkingConfig = <EnabledThinking>{budget_tokens: 512});
    test:assertTrue(provider is ai:Error, "A budget below the 1024 minimum must be rejected");
    if provider is ai:Error {
        test:assertTrue(provider.message().includes("at least 1024"),
                "Unexpected message: " + provider.message());
    }
}

// The default maxTokens (512) cannot accommodate any legal thinking budget.
@test:Config
function testThinkingRejectedWithDefaultMaxTokens() returns error? {
    ModelProvider|ai:Error provider = new (API_KEY, CLAUDE_SONNET_4_5, SERVICE_URL,
            thinkingConfig = <EnabledThinking>{budget_tokens: 1024});
    test:assertTrue(provider is ai:Error,
            "The default 'maxTokens' leaves no room for a thinking budget and must be rejected");
}

@test:Config
function testChatStreamSetsStreamFlag() returns error? {
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream =
        check streamProvider->chatStream([{role: ai:USER, content: "Say hello"}]);
    check chunkStream.close();
    map<json> payload = check getCapturedPayload("streamtest").ensureType();
    test:assertEquals(payload["stream"], true, "'chatStream' must set the stream flag");
}

// A generation that fails mid-flight must surface as an error. The transport still reports
// success, so without this the caller silently receives a truncated answer.
@test:Config
function testChatStreamSurfacesMidStreamErrorEvent() returns error? {
    stream<string, ai:Error?> textStream = check errorEventProvider->generateStream(`Say hello`);
    string collected = "";
    error? result = from string fragment in textStream
        do {
            collected += fragment;
        };
    test:assertTrue(result is error, "A mid-stream 'error' event must not end the stream cleanly");
    if result is error {
        test:assertTrue(result.message().includes("overloaded_error"),
                "The Anthropic error type must be preserved, got: " + result.message());
        test:assertTrue(result.message().includes("Overloaded"),
                "The Anthropic error message must be preserved, got: " + result.message());
    }
}

@test:Config
function testChatStreamSurfacesTruncatedStream() returns error? {
    stream<string, ai:Error?> textStream = check truncatedProvider->generateStream(`Say hello`);
    error? result = from string _ in textStream
        do {
        };
    test:assertTrue(result is error, "A stream ending before 'message_stop' must raise an error");
    if result is error {
        test:assertTrue(result.message().includes("before the response was complete"),
                "Unexpected message: " + result.message());
    }
}

@test:Config
function testChatStreamSurfacesMalformedChunk() returns error? {
    stream<string, ai:Error?> textStream = check malformedProvider->generateStream(`Say hello`);
    error? result = from string _ in textStream
        do {
        };
    test:assertTrue(result is error, "A malformed chunk must not be silently skipped");
    if result is error {
        test:assertTrue(result.message().includes("malformed"),
                "Unexpected message: " + result.message());
    }
}

// A `cache_creation` object carrying only one of its two TTL buckets used to fail the whole
// `message_start` conversion, silently dropping every chunk's id/model and the prompt tokens.
@test:Config
function testChatStreamToleratesPartialUsageFields() returns error? {
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream =
        check partialUsageProvider->chatStream([{role: ai:USER, content: "hi"}]);

    string? id = ();
    string? model = ();
    ai:CompletionTokenUsage? usage = ();
    check from ai:ChatCompletionChunk chunk in chunkStream
        do {
            string? chunkId = chunk.id;
            if chunkId is string {
                id = chunkId;
            }
            string? chunkModel = chunk.model;
            if chunkModel is string {
                model = chunkModel;
            }
            ai:CompletionTokenUsage? chunkUsage = chunk.usage;
            if chunkUsage is ai:CompletionTokenUsage {
                usage = chunkUsage;
            }
        };

    test:assertEquals(id, "msg_p", "Message id must survive a partial 'cache_creation'");
    test:assertEquals(model, "claude-sonnet-4-5", "Model must survive a partial 'cache_creation'");
    ai:CompletionTokenUsage finalUsage = check usage.ensureType();
    test:assertEquals(finalUsage.promptTokens, 9);
    test:assertEquals(finalUsage.completionTokens, 3);
    test:assertEquals(finalUsage.totalTokens, 12);
}

@test:Config
function testGenerateMethodWithTextChunk() returns error? {
    ai:TextChunk chunk = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    ai:TextChunk[] chunks = [chunk, chunk];
    int maxScore = 10;

    int rating = check claudeProvider->generate(`How would you rate this text chunk content out of ${maxScore}. ${chunk}.`);
    test:assertEquals(rating, 4);

    ReviewArray result = check claudeProvider->generate(`How would you rate these text chunks out of ${maxScore}. ${chunks}. Thank you!`);
    test:assertEquals(result, [review, review]);
}
