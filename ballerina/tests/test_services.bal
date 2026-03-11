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
    resource function post anthropic/messages(map<json> payload) returns AnthropicApiResponse|error {
        test:assertEquals(payload["model"], CLAUDE_3_7_SONNET_20250219);
        test:assertEquals(payload["max_tokens"], 512);
        test:assertEquals(payload["temperature"], 0.7d);

        json[] messages = check payload["messages"].ensureType();
        json[]? tools = check payload["tools"].ensureType();

        // Determine if this is a generate() call (has getResults tool) or a chat() call
        boolean isGenerateCall = false;
        boolean hasBuiltInTool = false;
        if tools is json[] && tools.length() > 0 {
            map<json> firstTool = check tools[0].ensureType();
            json? toolName = firstTool["name"];
            if toolName == GET_RESULTS_TOOL {
                isGenerateCall = true;
            }
            // Check for built-in tools (they have 'type' starting with "web_search_" or "code_execution_")
            foreach json tool in tools {
                map<json> toolMap = check tool.ensureType();
                string? toolType = check toolMap["type"].ensureType();
                if toolType is string &&
                        (toolType.startsWith("web_search") || toolType.startsWith("code_execution")) {
                    hasBuiltInTool = true;
                }
            }
        }

        if isGenerateCall {
            // Existing generate() path
            map<json> message = check messages[0].ensureType();
            json[]? content = check message["content"].ensureType();
            if content is () {
                test:assertFail("Expected content in the payload");
            }

            TextContentPart initialTextContent = check content[0].fromJsonWithType();
            string initialText = initialTextContent.text.toString();
            test:assertEquals(message["role"], "user");
            test:assertEquals(content, getExpectedContentParts(initialText));
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

        // Chat path: extract user message content
        string userContent = "";
        foreach json msg in messages {
            map<json> msgMap = check msg.ensureType();
            if msgMap["role"] == "user" {
                anydata msgContent = msgMap["content"];
                if msgContent is string {
                    userContent = msgContent;
                }
            }
        }

        // Chat with built-in tools - return text response
        if hasBuiltInTool {
            return getTestChatResponse(userContent);
        }

        // Chat with function tools - return tool call response
        if tools is json[] && tools.length() > 0 {
            return getTestChatToolCallResponse();
        }

        // Simple chat - return text response
        return getTestChatResponse(userContent);
    }
}

// Builds a chat response with text content
isolated function getTestChatResponse(string content) returns AnthropicApiResponse {
    return {
        id: "msg_chat_test",
        'type: "message",
        model: CLAUDE_3_7_SONNET_20250219,
        role: "assistant",
        content: [{
            'type: "text",
            text: "This is a mock response for: " + content
        }],
        stop_reason: "end_turn",
        stop_sequence: (),
        usage: {input_tokens: 50, output_tokens: 30}
    };
}

// Builds a chat response with a tool call
isolated function getTestChatToolCallResponse() returns AnthropicApiResponse {
    return {
        id: "msg_chat_tool_test",
        'type: "message",
        model: CLAUDE_3_7_SONNET_20250219,
        role: "assistant",
        content: [{
            'type: "tool_use",
            id: "toolu_test_123",
            name: "get_weather",
            input: {"city": "London"}
        }],
        stop_reason: "tool_use",
        stop_sequence: (),
        usage: {input_tokens: 80, output_tokens: 20}
    };
}
