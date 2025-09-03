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

isolated service /llm on new http:Listener(8080) {
    private map<int> retryCountMap = {};

    resource function post anthropic/messages(map<json> payload) returns AnthropicApiResponse|error {
        [json[], string] [_, initialText] = check validateAnthropicPayload(payload);
        return getTestServiceResponse(initialText);
    }

    resource function post anthropic\-retry/messages(map<json> payload) returns AnthropicApiResponse|error {
        [json[], string] [messages, initialText] = check validateAnthropicPayload(payload);

        int index;
        lock {
            index = updateRetryCountMap(initialText, self.retryCountMap);
        }

        check assertAnthropicMessages(messages, initialText, index);
        return getTestServiceResponse(initialText, index);
    }
}

isolated function validateAnthropicPayload(map<json> payload) returns [json[], string]|error {
    test:assertEquals(payload["model"], CLAUDE_3_7_SONNET_20250219);
    test:assertEquals(payload["max_tokens"], 512);
    test:assertEquals(payload["temperature"], 0.7d);

    json[] messages = check payload["messages"].ensureType();
    map<json> message = check messages[0].ensureType();
    test:assertEquals(message["role"], "user");

    json[]? content = check message["content"].ensureType();
    if content is () {
        test:assertFail("Expected content in the payload");
    }

    TextContentPart initialTextContent = check content[0].fromJsonWithType();
    string initialText = initialTextContent.text;

    json[]? tools = check payload["tools"].ensureType();
    if tools is () || tools.length() == 0 {
        test:assertFail("No tools in the payload");
    }

    map<json> tool = check tools[0].ensureType();
    map<json> parameters = check tool["input_schema"].ensureType();
    test:assertEquals(parameters, getExpectedParameterSchema(initialText),
        string `Parameter schema assertion failed for prompt starting with '${initialText}'`);

    return [messages, initialText];
}

isolated function assertAnthropicMessages(json[] messages, 
        string initialText, int index) returns error? {
    if index >= messages.length() {
        test:assertFail(string `Expected at least ${index + 1} message(s) in the payload`);
    }

    // Test input messages where the role is 'user'.
    json message = messages[index * 2];

    json|error? content = message.content.ensureType();

    if content is () {
        test:assertFail("Expected content in the payload");
    }

    if index == 0 {
        test:assertEquals(content, check getExpectedContentParts(initialText),
            string `Prompt assertion failed for prompt starting with '${initialText}'`);
        return;
    }

    if index == 1 {
        test:assertEquals(content, check getExpectedContentPartsForFirstRetryCall(initialText),
            string `Prompt assertion failed for prompt starting with '${initialText}' 
                on first attempt of the retry`);
        return;
    }

    test:assertEquals(content, check getExpectedContentPartsForSecondRetryCall(initialText),
            string `Prompt assertion failed for prompt starting with '${initialText}' on 
                second attempt of the retry`);
}

isolated function updateRetryCountMap(string initialText, map<int> retryCountMap) returns int {
    if retryCountMap.hasKey(initialText) {
        int index = retryCountMap.get(initialText) + 1;
        retryCountMap[initialText] = index;
        return index;
    }

    retryCountMap[initialText] = 0;
    return 0;
}
