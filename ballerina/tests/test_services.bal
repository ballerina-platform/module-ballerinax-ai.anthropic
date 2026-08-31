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

import ballerina/http;
import ballerina/test;

service /llm on new http:Listener(8080) {
    resource function post anthropic/messages(map<json> payload)returns AnthropicApiResponse|error {
        test:assertEquals(payload["model"], CLAUDE_3_7_SONNET_20250219);
        test:assertEquals(payload["max_tokens"], 512);
        test:assertEquals(payload["temperature"], 0.7d);

        json[] messages = check payload["messages"].ensureType();
        map<json> message = check messages[0].ensureType();
        json[]? content = check message["content"].ensureType();
        if content is () {
            test:assertFail("Expected content in the payload");
        }

        TextContentPart initialTextContent = check content[0].fromJsonWithType();
        string initialText = initialTextContent.text.toString();
        test:assertEquals(message["role"], "user");
        test:assertEquals(content, getExpectedContentParts(initialText));
        json[]? tools = check payload["tools"].ensureType();
        if tools is () || tools.length() == 0 {
            test:assertFail("No tools in the payload");
        }

        map<json> tool = check tools[0].ensureType();
        map<json>? parameters = check tool["input_schema"].ensureType();
        if parameters is () {
            test:assertFail("No parameters in the expected tool in the test with content: " 
                + content.toJsonString());
        }

        test:assertEquals(parameters, getExpectedParameterSchema(initialText),
                string `Test failed for prompt with initial content, ${initialText}`);
        return getTestServiceResponse(initialText);
    }
}

// Records the request payload each mock endpoint received, so tests can assert on what the
// provider actually sent. Asserting inside a resource would surface a failure as an opaque
// HTTP 500 instead of a readable test failure.
isolated map<json> capturedPayloads = {};

isolated function capturePayload(string key, json payload) {
    lock {
        capturedPayloads[key] = payload.clone();
    }
}

isolated function getCapturedPayload(string key) returns json {
    lock {
        return (capturedPayloads[key] ?: ()).clone();
    }
}

// Builds an SSE response from a raw event body.
isolated function sseResponse(string body) returns http:Response {
    http:Response res = new;
    res.setHeader("Content-Type", "text/event-stream");
    res.setTextPayload(body);
    return res;
}

service /streamtest on new http:Listener(9090) {
    resource function post anthropic/messages(map<json> payload, http:Caller caller) returns error? {
        capturePayload("streamtest", payload);

        http:Response res = new;
        res.setHeader("Content-Type", "text/event-stream");
        // A realistic Anthropic stream: message_start (id/model/input tokens), a text block
        // streamed in two text_delta fragments, a tool_use block whose arguments stream as
        // input_json_delta fragments keyed by index, then message_delta (stop reason + output
        // tokens) and message_stop.
        string sseBody =
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_1\",\"type\":\"message\"," +
            "\"role\":\"assistant\",\"model\":\"claude-3-7-sonnet-20250219\",\"content\":[]," +
            "\"usage\":{\"input_tokens\":10,\"output_tokens\":1}}}\n\n" +
            "event: content_block_start\n" +
            "data: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n" +
            "event: content_block_delta\n" +
            "data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\n\n" +
            "event: content_block_delta\n" +
            "data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\" world\"}}\n\n" +
            "event: content_block_stop\n" +
            "data: {\"type\":\"content_block_stop\",\"index\":0}\n\n" +
            "event: content_block_start\n" +
            "data: {\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"tool_use\"," +
            "\"id\":\"toolu_1\",\"name\":\"get_weather\",\"input\":{}}}\n\n" +
            "event: content_block_delta\n" +
            "data: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\"," +
            "\"partial_json\":\"{\\\"city\\\":\"}}\n\n" +
            "event: content_block_delta\n" +
            "data: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\"," +
            "\"partial_json\":\"\\\"Paris\\\"}\"}}\n\n" +
            "event: content_block_stop\n" +
            "data: {\"type\":\"content_block_stop\",\"index\":1}\n\n" +
            "event: message_delta\n" +
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"tool_use\"},\"usage\":{\"output_tokens\":7}}\n\n" +
            "event: message_stop\n" +
            "data: {\"type\":\"message_stop\"}\n\n";
        res.setTextPayload(sseBody);
        check caller->respond(res);
    }
}

// Captures what each request path sends, so tests can assert that configuration reaches the
// wire identically across `generate`, `chat`, and `chatStream`.
service /configtest on new http:Listener(9093) {

    // Non-streaming endpoint shared by `generate` and `chat`.
    resource function post plain/messages(map<json> payload) returns AnthropicApiResponse {
        capturePayload(payload.hasKey("tool_choice") ? "generate" : "chat", payload);
        return {
            id: "msg_cfg",
            'type: "message",
            role: "assistant",
            model: "claude-sonnet-4-5",
            content: [
                {
                    'type: "tool_use",
                    id: "toolu_cfg",
                    name: "getResults",
                    input: {result: "ok"}
                }
            ],
            stop_reason: "tool_use",
            stop_sequence: (),
            usage: {input_tokens: 1, output_tokens: 1}
        };
    }

    resource function post 'stream/messages(map<json> payload, http:Caller caller) returns error? {
        capturePayload("chatStream", payload);
        check caller->respond(sseResponse(
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_c\",\"type\":\"message\"," +
            "\"role\":\"assistant\",\"model\":\"claude-sonnet-4-5\",\"content\":[]," +
            "\"usage\":{\"input_tokens\":1,\"output_tokens\":1}}}\n\n" +
            "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"));
    }
}

// Streams that fail after the transport has already reported success. Each one models a way
// a generation can break mid-flight without the HTTP layer noticing.
service /streamedge on new http:Listener(9092) {

    // Generation fails partway through with an Anthropic `error` event.
    resource function post errorevent/messages(map<json> payload, http:Caller caller) returns error? {
        capturePayload("errorevent", payload);
        check caller->respond(sseResponse(
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_e\",\"type\":\"message\"," +
            "\"role\":\"assistant\",\"model\":\"claude-sonnet-4-5\",\"content\":[]," +
            "\"usage\":{\"input_tokens\":5,\"output_tokens\":1}}}\n\n" +
            "event: content_block_delta\n" +
            "data: {\"type\":\"content_block_delta\",\"index\":0," +
            "\"delta\":{\"type\":\"text_delta\",\"text\":\"Partial\"}}\n\n" +
            "event: error\n" +
            "data: {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\"," +
            "\"message\":\"Overloaded\"}}\n\n"));
    }

    // Connection drops mid-generation: content arrives, `message_stop` never does.
    resource function post truncated/messages(map<json> payload, http:Caller caller) returns error? {
        capturePayload("truncated", payload);
        check caller->respond(sseResponse(
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_t\",\"type\":\"message\"," +
            "\"role\":\"assistant\",\"model\":\"claude-sonnet-4-5\",\"content\":[]," +
            "\"usage\":{\"input_tokens\":5,\"output_tokens\":1}}}\n\n" +
            "event: content_block_delta\n" +
            "data: {\"type\":\"content_block_delta\",\"index\":0," +
            "\"delta\":{\"type\":\"text_delta\",\"text\":\"Partial\"}}\n\n"));
    }

    // A chunk whose `data` is not valid JSON.
    resource function post malformed/messages(map<json> payload, http:Caller caller) returns error? {
        capturePayload("malformed", payload);
        check caller->respond(sseResponse(
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_m\",\"type\":\"message\"," +
            "\"role\":\"assistant\",\"model\":\"claude-sonnet-4-5\",\"content\":[]," +
            "\"usage\":{\"input_tokens\":5,\"output_tokens\":1}}}\n\n" +
            "event: content_block_delta\n" +
            "data: {not-json\n\n"));
    }

    // A well-formed stream carrying a `cache_creation` object with only one of its two
    // TTL buckets - the shape that used to wipe out every chunk's id/model/usage.
    resource function post partialusage/messages(map<json> payload, http:Caller caller) returns error? {
        capturePayload("partialusage", payload);
        check caller->respond(sseResponse(
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_p\",\"type\":\"message\"," +
            "\"role\":\"assistant\",\"model\":\"claude-sonnet-4-5\",\"content\":[]," +
            "\"usage\":{\"input_tokens\":9,\"output_tokens\":1," +
            "\"cache_creation\":{\"ephemeral_5m_input_tokens\":4}}}}\n\n" +
            "event: content_block_delta\n" +
            "data: {\"type\":\"content_block_delta\",\"index\":0," +
            "\"delta\":{\"type\":\"text_delta\",\"text\":\"Hi\"}}\n\n" +
            "event: message_delta\n" +
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"}," +
            "\"usage\":{\"output_tokens\":3}}\n\n" +
            "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"));
    }
}
