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

        json[] messages = check payload["messages"].ensureType();
        map<json> message = check messages[0].ensureType();
        string? content = check message["content"].ensureType();
        if content is () {
            test:assertFail("Expected content in the payload");
        }

        test:assertEquals(content, getExpectedPrompt(content));
        test:assertEquals(message["role"], "user");
        json[]? tools = check payload["tools"].ensureType();
        if tools is () || tools.length() == 0 {
            test:assertFail("No tools in the payload");
        }

        map<json> tool = check tools[0].ensureType();
        map<json>? parameters = check tool["input_schema"].ensureType();
        if parameters is () {
            test:assertFail("No parameters in the expected tool in the test with content: " + content);
        }

        test:assertEquals(parameters, getExpectedParameterSchema(content));
        return getTestServiceResponse(content);
    }
}
