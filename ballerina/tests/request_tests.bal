// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.org).
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
import ballerina/test;

const CAPTURE_SERVICE_URL = "http://localhost:8080/llm/anthropic/capture";
const ERROR_SERVICE_URL = "http://localhost:8080/llm/anthropic/failing";
const MALFORMED_SERVICE_URL = "http://localhost:8080/llm/anthropic/malformed";

isolated function getCapturedRequest(string model, string method) returns map<json>|error {
    json request;
    lock {
        request = capturedRequests[string `${model}:${method}`].clone();
    }
    return request.cloneWithType();
}

@test:Config {
    dataProvider: modelsWithoutTemperature
}
function testTemperatureIsOmittedForModelsThatDoNotSupportIt(ANTHROPIC_MODEL_NAMES model) returns error? {
    ModelProvider provider = check new (API_KEY, model, CAPTURE_SERVICE_URL);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
    test:assertFalse((check getCapturedRequest(model, "chat")).hasKey("temperature"));
    test:assertFalse((check getCapturedRequest(model, "generate")).hasKey("temperature"));
}

function modelsWithoutTemperature() returns ANTHROPIC_MODEL_NAMES[][] => [[CLAUDE_OPUS_4_7], [CLAUDE_OPUS_4_8]];

@test:Config
function testTemperatureIsSentForModelsThatSupportIt() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, CAPTURE_SERVICE_URL, temperature = 0.3);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
    test:assertEquals((check getCapturedRequest(CLAUDE_SONNET_4_6, "chat"))["temperature"], 0.3d);
    test:assertEquals((check getCapturedRequest(CLAUDE_SONNET_4_6, "generate"))["temperature"], 0.3d);
}

@test:Config
function testApiErrorResponseIsIncludedInChatError() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, ERROR_SERVICE_URL);
    ai:ChatAssistantMessage|ai:Error result = provider->chat([{role: ai:USER, content: "Hi"}]);
    if result !is ai:LlmInvalidResponseError {
        test:assertFail("Expected an ai:LlmInvalidResponseError");
    }
    test:assertEquals(result.message(), "Anthropic API request failed with status 404: "
        + "{\"type\":\"error\",\"error\":{\"type\":\"not_found_error\",\"message\":\"model: claude-3-7-sonnet-20250219\"}}");
}

@test:Config
function testApiErrorResponseIsIncludedInGenerateError() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, ERROR_SERVICE_URL);
    int|ai:Error result = provider->generate(`Pick a number`);
    if result !is ai:LlmInvalidResponseError {
        test:assertFail("Expected an ai:LlmInvalidResponseError");
    }
    test:assertTrue(result.message().startsWith("Anthropic API request failed with status 404: "));
}

@test:Config
function testMalformedResponseReturnsInvalidResponseError() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, MALFORMED_SERVICE_URL);
    ai:ChatAssistantMessage|ai:Error result = provider->chat([{role: ai:USER, content: "Hi"}]);
    if result !is ai:LlmInvalidResponseError {
        test:assertFail("Expected an ai:LlmInvalidResponseError");
    }
    test:assertEquals(result.message(), "Unexpected response format from Anthropic API");
}

@test:Config
function testConnectionFailureReturnsConnectionError() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, "http://localhost:8099/unavailable");
    ai:ChatAssistantMessage|ai:Error result = provider->chat([{role: ai:USER, content: "Hi"}]);
    test:assertTrue(result is ai:LlmConnectionError);
}
