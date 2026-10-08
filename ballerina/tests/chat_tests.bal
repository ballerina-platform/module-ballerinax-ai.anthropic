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

const CHAT_SERVICE_URL = "http://localhost:8080/llm/anthropic/chat";

final ModelProvider chatProvider = check new (API_KEY, CLAUDE_3_7_SONNET_20250219, CHAT_SERVICE_URL);

isolated function getChatRequestMessages(string firstUserMessage) returns json {
    lock {
        return chatRequestMessages[firstUserMessage].clone();
    }
}

@test:Config
function testChatMapsToolCallHistoryToToolUseAndToolResultBlocks() returns error? {
    ai:ChatMessage[] messages = [
        {role: ai:USER, content: "What is 1+3-5?"},
        {role: ai:ASSISTANT, toolCalls: [{name: "sum", arguments: {a: 1, b: 3}, id: "toolu_1"}]},
        {role: "function", name: "sum", content: "4.0", id: "toolu_1"}
    ];
    _ = check chatProvider->chat(messages);
    test:assertEquals(getChatRequestMessages("What is 1+3-5?"), [
        {role: "user", content: "What is 1+3-5?"},
        {role: "assistant", content: [{'type: "tool_use", id: "toolu_1", name: "sum", input: {a: 1, b: 3}}]},
        {role: "user", content: [{'type: "tool_result", tool_use_id: "toolu_1", content: "4.0"}]}
    ]);
}

@test:Config
function testChatGroupsToolResultsOfSameTurnIntoSingleUserMessage() returns error? {
    ai:ChatMessage[] messages = [
        {role: ai:USER, content: "What is 1+3 and 2*5?"},
        {
            role: ai:ASSISTANT,
            content: "Let me calculate both.",
            toolCalls: [
                {name: "sum", arguments: {a: 1, b: 3}, id: "toolu_1"},
                {name: "multiply", arguments: {a: 2, b: 5}, id: "toolu_2"}
            ]
        },
        {role: "function", name: "sum", content: "4.0", id: "toolu_1"},
        {role: "function", name: "multiply", content: "10.0", id: "toolu_2"}
    ];
    _ = check chatProvider->chat(messages);
    test:assertEquals(getChatRequestMessages("What is 1+3 and 2*5?"), [
        {role: "user", content: "What is 1+3 and 2*5?"},
        {
            role: "assistant",
            content: [
                {'type: "text", text: "Let me calculate both."},
                {'type: "tool_use", id: "toolu_1", name: "sum", input: {a: 1, b: 3}},
                {'type: "tool_use", id: "toolu_2", name: "multiply", input: {a: 2, b: 5}}
            ]
        },
        {
            role: "user",
            content: [
                {'type: "tool_result", tool_use_id: "toolu_1", content: "4.0"},
                {'type: "tool_result", tool_use_id: "toolu_2", content: "10.0"}
            ]
        }
    ]);
}

@test:Config
function testChatFallsBackToFunctionResultsTextForToolCallsWithoutIds() returns error? {
    ai:ChatMessage[] messages = [
        {role: ai:USER, content: "What is 1+3?"},
        {role: ai:ASSISTANT, toolCalls: [{name: "sum", arguments: {a: 1, b: 3}}]},
        {role: "function", name: "sum", content: "4.0"}
    ];
    _ = check chatProvider->chat(messages);
    test:assertEquals(getChatRequestMessages("What is 1+3?"), [
        {role: "user", content: "What is 1+3?"},
        {role: "user", content: string `<function_results>\nFunction: sum\nOutput: 4.0\n</function_results>`}
    ]);
}

@test:Config
function testChatPreservesToolUseIdFromResponse() returns error? {
    ai:ChatAssistantMessage response = check chatProvider->chat([{role: ai:USER, content: "What is 4+5?"}]);
    test:assertEquals(response.toolCalls, [{name: "sum", arguments: {a: 4, b: 5}, id: "toolu_response"}]);
}

@test:Config
function testChatSendsEmptyToolResultForFunctionMessageWithoutContent() returns error? {
    ai:ChatMessage[] messages = [
        {role: ai:USER, content: "Clear the cache"},
        {role: ai:ASSISTANT, toolCalls: [{name: "clearCache", arguments: {}, id: "toolu_1"}]},
        {role: "function", name: "clearCache", id: "toolu_1"}
    ];
    _ = check chatProvider->chat(messages);
    test:assertEquals(getChatRequestMessages("Clear the cache"), [
        {role: "user", content: "Clear the cache"},
        {role: "assistant", content: [{'type: "tool_use", id: "toolu_1", name: "clearCache", input: {}}]},
        {role: "user", content: [{'type: "tool_result", tool_use_id: "toolu_1", content: ""}]}
    ]);
}

@test:Config
function testChatSkipsEmptyAssistantContent() returns error? {
    ai:ChatMessage[] messages = [
        {role: ai:USER, content: "Hi"},
        {role: ai:ASSISTANT, content: ""},
        {role: ai:USER, content: "Are you there?"}
    ];
    _ = check chatProvider->chat(messages);
    test:assertEquals(getChatRequestMessages("Hi"), [
        {role: "user", content: "Hi"},
        {role: "user", content: "Are you there?"}
    ]);
}
