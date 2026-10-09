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
import ballerina/http;
import ballerina/test;

isolated map<json> chatRequestMessages = {};

service /llm on new http:Listener(8080) {
    resource function post anthropic/messages(map<json> payload)returns AnthropicApiResponse|error {
        test:assertEquals(payload["model"], CLAUDE_SONNET_4_6);
        test:assertEquals(payload["max_tokens"], 4096);
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

    resource function post anthropic/chat/messages(map<json> payload) returns AnthropicApiResponse|error {
        json[] messages = check payload["messages"].ensureType();
        map<json> firstMessage = check messages[0].ensureType();
        string key = firstMessage["content"].toString();
        lock {
            chatRequestMessages[key] = messages.cloneReadOnly();
        }
        return {
            id: "test-id",
            model: CLAUDE_SONNET_4_6,
            'type: "message",
            stop_reason: "tool_use",
            role: "assistant",
            stop_sequence: (),
            usage: {input_tokens: 10, output_tokens: 5},
            content: [{'type: "tool_use", id: "toolu_response", name: "sum", input: {a: 4, b: 5}}]
        };
    }
}

service /temptest on new http:Listener(7070) {
    resource function post anthropic/messages(map<json> payload) returns AnthropicApiResponse|error {
        string modelType = check payload["model"].ensureType();
        if modelType == CLAUDE_OPUS_4_7 || modelType == CLAUDE_OPUS_4_8 ||
                modelType == CLAUDE_OPUS_5_5 || modelType == CLAUDE_SONNET_5_5 {
            test:assertFalse(payload.hasKey("temperature"),
                string `temperature must be absent for model: ${modelType}`);
        } else {
            test:assertEquals(payload["temperature"], DEFAULT_TEMPERATURE,
                string `temperature must be present for model: ${modelType}`);
        }
        return {
            id: "temp-test-id",
            model: modelType,
            'type: "message",
            stop_reason: "end_turn",
            role: ai:ASSISTANT,
            stop_sequence: (),
            usage: {input_tokens: 10, output_tokens: 5},
            content: [{'type: "text", text: "ok"}]
        };
    }

    resource function post generate/messages(map<json> payload) returns AnthropicApiResponse|error {
        string modelType = check payload["model"].ensureType();
        if modelType == CLAUDE_OPUS_5_5 || modelType == CLAUDE_SONNET_5_5 {
            test:assertEquals(payload["tool_choice"], {'type: "auto"},
                string `forced tool_choice must not be sent for model: ${modelType}`);
            test:assertTrue(payload.hasKey("system"),
                string `the getResults instruction must be sent for model: ${modelType}`);
        } else {
            test:assertEquals(payload["tool_choice"], {'type: "tool", name: "getResults"},
                string `tool_choice must force getResults for model: ${modelType}`);
            test:assertFalse(payload.hasKey("system"));
        }
        return {
            id: "generate-test-id",
            model: modelType,
            'type: "message",
            stop_reason: "tool_use",
            role: ai:ASSISTANT,
            stop_sequence: (),
            usage: {input_tokens: 10, output_tokens: 5},
            content: [{'type: "tool_use", id: "toolu_gen", name: "getResults", input: {result: 7}}]
        };
    }
}

service /chat on new http:Listener(9090) {
    resource function post anthropic/messages(map<json> payload) returns AnthropicApiResponse|error {
        json[] messages = check payload["messages"].ensureType();
        test:assertEquals(messages.length(), 3, "Expected 3 messages in the serialized Anthropic payload");

        // message[0]: user message — always a plain string for these tests
        map<json> firstMsg = check messages[0].ensureType();
        string firstContent = check firstMsg["content"].ensureType();

        // message[1]: assistant must be serialized as a content block array, not a plain string
        map<json> assistantMsg = check messages[1].ensureType();
        test:assertEquals(assistantMsg["role"], "assistant");
        json[] assistantContent = check assistantMsg["content"].ensureType();
        map<json> toolUseBlock = check assistantContent[0].ensureType();
        test:assertEquals(toolUseBlock["type"], "tool_use", "Assistant tool call must use 'tool_use' block");
        test:assertEquals(toolUseBlock["id"], "toolu_001");

        // message[2]: user message must carry tool_result blocks, never plain XML text
        map<json> userMsg = check messages[2].ensureType();
        test:assertEquals(userMsg["role"], "user");
        json[] userContent = check userMsg["content"].ensureType();
        map<json> firstResult = check userContent[0].ensureType();
        test:assertEquals(firstResult["type"], "tool_result", "Tool result must be 'tool_result' block, not XML text");
        test:assertEquals(firstResult["tool_use_id"], "toolu_001", "tool_use_id must match the original tool call id");

        if firstContent == "Add 5 and 3, subtract 4 from 10" {
            // Parallel test: assistant must have 2 tool_use blocks,
            // and both results must be batched into a single user message
            test:assertEquals(assistantContent.length(), 2, "Expected 2 tool_use blocks for parallel tool calls");
            test:assertEquals(userContent.length(), 2, "Expected both parallel tool results in one user message");
            map<json> secondResult = check userContent[1].ensureType();
            test:assertEquals(secondResult["type"], "tool_result");
            test:assertEquals(secondResult["tool_use_id"], "toolu_002");
            test:assertEquals(firstResult["content"], "8");
            test:assertEquals(secondResult["content"], "6");
            return {
                id: "parallel-test-id",
                model: CLAUDE_SONNET_4_6,
                'type: "message",
                stop_reason: "end_turn",
                role: ai:ASSISTANT,
                stop_sequence: (),
                usage: {input_tokens: 70, output_tokens: 15},
                content: [{'type: "text", text: "The answers are 8 and 6."}]
            };
        }

        // Multi-round test: single tool_use, single tool_result
        test:assertEquals(assistantContent.length(), 1, "Expected 1 tool_use block");
        test:assertEquals(userContent.length(), 1, "Expected 1 tool_result block");
        test:assertEquals(toolUseBlock["name"], "add");
        test:assertEquals(firstResult["content"], "8");
        return {
            id: "multi-round-test-id",
            model: CLAUDE_SONNET_4_6,
            'type: "message",
            stop_reason: "end_turn",
            role: ai:ASSISTANT,
            stop_sequence: (),
            usage: {input_tokens: 50, output_tokens: 10},
            content: [{'type: "text", text: "The answer is 8."}]
        };
    }
}
