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
const HTML_SERVICE_URL = "http://localhost:8080/llm/anthropic/html";
const TRUNCATED_SERVICE_URL = "http://localhost:8080/llm/anthropic/truncated";
const NO_TOOL_CALL_SERVICE_URL = "http://localhost:8080/llm/anthropic/notool";
const THINKING_SERVICE_URL = "http://localhost:8080/llm/anthropic/thinking";
const MULTIPLE_TOOLS_SERVICE_URL = "http://localhost:8080/llm/anthropic/multipletools";
const INVALID_ARGS_SERVICE_URL = "http://localhost:8080/llm/anthropic/invalidargs";

isolated function getCapturedRequest(string testId, string method) returns map<json>|error {
    json request;
    lock {
        request = capturedRequests[string `${testId}:${method}`].clone();
    }
    return request.cloneWithType();
}

isolated function getCapturedApiVersion(string testId, string method) returns string|error {
    json apiVersion;
    lock {
        apiVersion = capturedRequests[string `${testId}:${method}:anthropic-version`].clone();
    }
    return apiVersion.ensureType();
}

@test:Config
function testDefaultApiVersion() returns error? {
    string testId = "default-api-version";
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
    test:assertEquals(check getCapturedApiVersion(testId, "chat"), "2023-06-01");
    test:assertEquals(check getCapturedApiVersion(testId, "generate"), "2023-06-01");
}

@test:Config
function testApiVersion20261021IsSentAndTemperatureIsNotSent() returns error? {
    string testId = "api-version-2026-10-21";
    // Sonnet 4.6 supports temperature on 2023-06-01, but no model supports it on 2026-10-21.
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`,
        temperature = 0.3, apiVersion = API_VERSION_2026_10_21);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
    test:assertEquals(check getCapturedApiVersion(testId, "chat"), "2026-10-21");
    test:assertEquals(check getCapturedApiVersion(testId, "generate"), "2026-10-21");
    test:assertFalse((check getCapturedRequest(testId, "chat")).hasKey("temperature"));
    test:assertFalse((check getCapturedRequest(testId, "generate")).hasKey("temperature"));
}

@test:Config
function testTemperatureWarningOnApiVersion20261021() {
    // Every value is rejected on 2026-10-21, including the default, on every model.
    ANTHROPIC_MODEL_NAMES[] models = [CLAUDE_SONNET_4_6, CLAUDE_SONNET_5_5, CLAUDE_OPUS_5_5];
    decimal[] temperatures = [0.3, 1.0];
    foreach ANTHROPIC_MODEL_NAMES model in models {
        foreach decimal temperature in temperatures {
            string? warning = temperatureWarning(model, temperature, API_VERSION_2026_10_21);
            if warning !is string {
                test:assertFail(string `expected a temperature warning for ${model} with ${temperature}`);
            }
            test:assertTrue(warning.includes("2026-10-21"), "the warning must name the API version");
        }
    }
    test:assertEquals(temperatureWarning(CLAUDE_SONNET_4_6, (), API_VERSION_2026_10_21), ());
}

function temperatureTestModels() returns ANTHROPIC_MODEL_NAMES[][] => [[CLAUDE_SONNET_4_6], [CLAUDE_OPUS_4_7]];

@test:Config {
    dataProvider: temperatureTestModels
}
function testTemperatureIsOmittedWhenNotSet(ANTHROPIC_MODEL_NAMES model) returns error? {
    string testId = string `omit-temperature-${model}`;
    ModelProvider provider = check new (API_KEY, model, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
    test:assertFalse((check getCapturedRequest(testId, "chat")).hasKey("temperature"));
    test:assertFalse((check getCapturedRequest(testId, "generate")).hasKey("temperature"));
}

function temperatureSupportedModels() returns ANTHROPIC_MODEL_NAMES[][] =>
    [[CLAUDE_HAIKU_4_5], [CLAUDE_OPUS_4_5], [CLAUDE_OPUS_4_6], [CLAUDE_SONNET_4_6]];

function temperatureUnsupportedModels() returns ANTHROPIC_MODEL_NAMES[][] =>
    [[CLAUDE_OPUS_4_7], [CLAUDE_OPUS_4_8], [CLAUDE_OPUS_5], [CLAUDE_OPUS_5_5], [CLAUDE_FABLE_5], [CLAUDE_FABLE_5_1],
        ...defaultTemperatureOnlyModels()];

function defaultTemperatureOnlyModels() returns ANTHROPIC_MODEL_NAMES[][] =>
    [[CLAUDE_SONNET_5], [CLAUDE_SONNET_5_5], [CLAUDE_HAIKU_5_5]];

@test:Config {
    dataProvider: temperatureSupportedModels
}
function testTemperatureIsSentWhenSet(ANTHROPIC_MODEL_NAMES model) returns error? {
    string testId = string `send-temperature-${model}`;
    ModelProvider provider = check new (API_KEY, model, string `${CAPTURE_SERVICE_URL}/${testId}`,
        temperature = 0.3);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
    test:assertEquals((check getCapturedRequest(testId, "chat"))["temperature"], 0.3d);
    test:assertEquals((check getCapturedRequest(testId, "generate"))["temperature"], 0.3d);
}

@test:Config {
    dataProvider: temperatureUnsupportedModels
}
function testTemperatureIsNotSentForUnsupportedModels(ANTHROPIC_MODEL_NAMES model) returns error? {
    string testId = string `skip-temperature-${model}`;
    ModelProvider provider = check new (API_KEY, model, string `${CAPTURE_SERVICE_URL}/${testId}`,
        temperature = 0.3);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
    test:assertFalse((check getCapturedRequest(testId, "chat")).hasKey("temperature"));
    test:assertFalse((check getCapturedRequest(testId, "generate")).hasKey("temperature"));
}

@test:Config {
    dataProvider: temperatureUnsupportedModels
}
function testTemperatureWarningOnUnsupportedModels(ANTHROPIC_MODEL_NAMES model) {
    string? warning = temperatureWarning(model, 0.3);
    if warning !is string {
        test:assertFail(string `expected a temperature warning for ${model}`);
    }
    test:assertTrue(warning.includes(model), "the warning must name the model");
    test:assertTrue(warning.includes("0.3"), "the warning must include the temperature value");
}

@test:Config {
    dataProvider: defaultTemperatureOnlyModels
}
function testDefaultTemperatureIsSentForDefaultTemperatureOnlyModels(ANTHROPIC_MODEL_NAMES model) returns error? {
    string testId = string `default-temperature-${model}`;
    ModelProvider provider = check new (API_KEY, model, string `${CAPTURE_SERVICE_URL}/${testId}`,
        temperature = 1.0);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
    test:assertEquals((check getCapturedRequest(testId, "chat"))["temperature"], 1.0d);
    test:assertEquals((check getCapturedRequest(testId, "generate"))["temperature"], 1.0d);
}

@test:Config {
    dataProvider: defaultTemperatureOnlyModels
}
function testNonDefaultTemperatureWarningOnDefaultTemperatureOnlyModels(ANTHROPIC_MODEL_NAMES model) {
    string? warning = temperatureWarning(model, 0.3);
    if warning !is string {
        test:assertFail(string `expected a temperature warning for ${model}`);
    }
    test:assertTrue(warning.includes("only the default temperature of 1.0"),
        "the warning must state that only the default is supported");
}

@test:Config
function testDefaultTemperatureWarningOnTemperatureUnsupportedModels() {
    // These models reject even the default value.
    test:assertTrue(temperatureWarning(CLAUDE_OPUS_5_5, 1.0) is string);
    test:assertTrue(temperatureWarning(CLAUDE_FABLE_5_1, 1.0) is string);
}

@test:Config
function testNoTemperatureWarningWhenNotApplicable() {
    // No warning when temperature is unset, on models that support it, or when the default is set
    // on models that support only the default.
    test:assertEquals(temperatureWarning(CLAUDE_OPUS_5_5, ()), ());
    test:assertEquals(temperatureWarning(CLAUDE_SONNET_4_6, ()), ());
    foreach ANTHROPIC_MODEL_NAMES[] models in temperatureSupportedModels() {
        test:assertEquals(temperatureWarning(models[0], 0.3), (), string `unexpected warning for ${models[0]}`);
    }
    foreach ANTHROPIC_MODEL_NAMES[] models in defaultTemperatureOnlyModels() {
        test:assertEquals(temperatureWarning(models[0], 1.0), (), string `unexpected warning for ${models[0]}`);
        test:assertEquals(temperatureWarning(models[0], 1), (), string `unexpected warning for ${models[0]}`);
    }
}

function autoToolChoiceModels() returns ANTHROPIC_MODEL_NAMES[][] =>
    [[CLAUDE_OPUS_5_5], [CLAUDE_SONNET_5_5], [CLAUDE_FABLE_5_1]];

function forcedToolChoiceModels() returns ANTHROPIC_MODEL_NAMES[][] =>
    [[CLAUDE_SONNET_4_6], [CLAUDE_OPUS_4_8], [CLAUDE_HAIKU_5_5], [CLAUDE_SONNET_5], [CLAUDE_OPUS_5], [CLAUDE_FABLE_5]];

@test:Config {
    dataProvider: autoToolChoiceModels
}
function testGenerateUsesAutoToolChoiceForModelsWithoutForcedToolChoice(ANTHROPIC_MODEL_NAMES model) returns error? {
    string testId = string `auto-tool-choice-${model}`;
    ModelProvider provider = check new (API_KEY, model, string `${CAPTURE_SERVICE_URL}/${testId}`);
    int result = check provider->generate(`Pick a number`);
    test:assertEquals(result, 1);

    map<json> request = check getCapturedRequest(testId, "generate");
    test:assertEquals(check request.tool_choice, {'type: "auto"});
    test:assertEquals(check request.system, GET_RESULTS_TOOL_INSTRUCTION);
    json[] tools = check request.tools.ensureType();
    test:assertEquals(check tools[0].name, GET_RESULTS_TOOL);
}

@test:Config {
    dataProvider: forcedToolChoiceModels
}
function testGenerateUsesForcedToolChoiceForOtherModels(ANTHROPIC_MODEL_NAMES model) returns error? {
    string testId = string `forced-tool-choice-${model}`;
    ModelProvider provider = check new (API_KEY, model, string `${CAPTURE_SERVICE_URL}/${testId}`);
    int result = check provider->generate(`Pick a number`);
    test:assertEquals(result, 1);

    map<json> request = check getCapturedRequest(testId, "generate");
    test:assertEquals(check request.tool_choice, {'type: "tool", name: GET_RESULTS_TOOL});
    test:assertFalse(request.hasKey("system"));
}

@test:Config
function testDefaultMaxTokens() returns error? {
    string testId = "default-max-tokens";
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
    test:assertEquals((check getCapturedRequest(testId, "chat"))["max_tokens"], 4096);
    test:assertEquals((check getCapturedRequest(testId, "generate"))["max_tokens"], 4096);
}

@test:Config
function testTruncatedResponseReturnsMaxTokensHint() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_OPUS_5_5, TRUNCATED_SERVICE_URL);
    int[]|ai:Error result = provider->generate(`List some numbers`);
    if result !is ai:LlmInvalidGenerationError {
        test:assertFail("Expected an ai:LlmInvalidGenerationError");
    }
    test:assertTrue(result.message().endsWith("The response was truncated as it reached the maximum token limit."));
}

@test:Config
function testGenerateIgnoresThinkingAndTextBlocksBeforeToolCall() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_OPUS_5_5, THINKING_SERVICE_URL);
    int result = check provider->generate(`Pick a number`);
    test:assertEquals(result, 42);
}

@test:Config
function testGenerateUsesFirstToolCallWhenMultipleAreReturned() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_OPUS_5_5, MULTIPLE_TOOLS_SERVICE_URL);
    int result = check provider->generate(`Pick a number`);
    test:assertEquals(result, 7);
}

@test:Config
function testGenerateWithInvalidToolArgumentsReturnsError() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_OPUS_5_5, INVALID_ARGS_SERVICE_URL);
    int|ai:Error result = provider->generate(`Pick a number`);
    if result !is ai:LlmInvalidGenerationError {
        test:assertFail("Expected an ai:LlmInvalidGenerationError");
    }
    test:assertFalse(result.message().includes("truncated"));
}

@test:Config {
    dataProvider: autoToolChoiceModels
}
function testAutoToolChoiceRequestWithDocument(ANTHROPIC_MODEL_NAMES model) returns error? {
    string testId = string `auto-tool-choice-doc-${model}`;
    ModelProvider provider = check new (API_KEY, model, string `${CAPTURE_SERVICE_URL}/${testId}`);
    ai:TextDocument doc = {content: "The meeting is in room 1."};
    int _ = check provider->generate(`Which room is mentioned in ${doc}?`);

    map<json> request = check getCapturedRequest(testId, "generate");
    test:assertEquals(check request.tool_choice, {'type: "auto"});
    test:assertEquals(check request.system, GET_RESULTS_TOOL_INSTRUCTION);
    test:assertFalse(request.hasKey("temperature"));
    json[] messages = check request.messages.ensureType();
    test:assertEquals(messages.length(), 1);
    test:assertEquals(check messages[0].role, "user");
}

@test:Config
function testGenerateWithoutToolCallReturnsError() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_OPUS_5_5, NO_TOOL_CALL_SERVICE_URL);
    int|ai:Error result = provider->generate(`Pick a number`);
    if result !is ai:Error {
        test:assertFail("Expected an ai:Error");
    }
    test:assertEquals(result.message(), "No relevant response from the LLM");
}

@test:Config
function testApiErrorResponseIsIncludedInChatError() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, ERROR_SERVICE_URL);
    ai:ChatAssistantMessage|ai:Error result = provider->chat([{role: ai:USER, content: "Hi"}]);
    if result !is ai:LlmInvalidResponseError {
        test:assertFail("Expected an ai:LlmInvalidResponseError");
    }
    string message = result.message();
    test:assertTrue(message.startsWith("Anthropic API request failed with status 404: "));
    test:assertTrue(message.includes("not_found_error"));
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
function testNonJsonResponseReturnsInvalidResponseError() returns error? {
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, HTML_SERVICE_URL);
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
