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

service /streamtest on new http:Listener(9090) {
    resource function post anthropic/messages(map<json> payload, http:Caller caller) returns error? {
        test:assertTrue(payload.hasKey("stream"), "stream flag must be set");
        test:assertEquals(payload["stream"], true);

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
