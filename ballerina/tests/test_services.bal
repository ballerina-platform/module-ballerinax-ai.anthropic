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

        // Chat with built-in tools - validate tools payload and return text response
        if hasBuiltInTool {
            json[] toolsArr = check payload["tools"].ensureType();
            if userContent == "Search with allowed domains" {
                check validateWebSearchToolPayload(toolsArr, allowedDomains = ["example.com", "test.org"]);
            } else if userContent == "Search with blocked domains" {
                check validateWebSearchToolPayload(toolsArr, blockedDomains = ["spam.com"]);
            } else if userContent == "Search with location" {
                check validateWebSearchToolPayload(toolsArr, userLocation = {
                    "type": "approximate",
                    "city": "San Francisco",
                    "region": "California",
                    "country": "US",
                    "timezone": "America/Los_Angeles"
                });
            } else if userContent == "Search with max uses" {
                check validateWebSearchToolPayload(toolsArr, maxUses = 3);
            } else if userContent == "Execute code custom type" {
                map<json> tool = check toolsArr[0].ensureType();
                test:assertEquals(tool["type"], "code_execution_20250522");
                test:assertEquals(tool["name"], "code_execution");
            } else if userContent == "Mixed tools test" {
                test:assertEquals(toolsArr.length(), 2);
                // One should be a function tool (has input_schema), other a built-in tool
                map<json> firstTool = check toolsArr[0].ensureType();
                map<json> secondTool = check toolsArr[1].ensureType();
                test:assertEquals(firstTool["name"], "get_weather");
                test:assertTrue(firstTool.hasKey("input_schema"));
                test:assertEquals(secondTool["name"], "web_search");
                string? secondType = check secondTool["type"].ensureType();
                test:assertTrue(secondType is string && secondType.startsWith("web_search"));
            }
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

// Validates a web search tool payload in the tools array
isolated function validateWebSearchToolPayload(json[] tools,
        string[]? allowedDomains = (), string[]? blockedDomains = (),
        map<json>? userLocation = (), int? maxUses = ()) returns error? {
    map<json> tool = check tools[0].ensureType();
    test:assertEquals(tool["name"], "web_search");
    string? toolType = check tool["type"].ensureType();
    test:assertTrue(toolType is string && toolType.startsWith("web_search"));
    if allowedDomains is string[] {
        json[] actual = check tool["allowed_domains"].ensureType();
        test:assertEquals(actual, allowedDomains.toJson());
    }
    if blockedDomains is string[] {
        json[] actual = check tool["blocked_domains"].ensureType();
        test:assertEquals(actual, blockedDomains.toJson());
    }
    if userLocation is map<json> {
        map<json> actual = check tool["user_location"].ensureType();
        test:assertEquals(actual, userLocation);
    }
    if maxUses is int {
        int actual = check tool["max_uses"].ensureType();
        test:assertEquals(actual, maxUses);
    }
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
