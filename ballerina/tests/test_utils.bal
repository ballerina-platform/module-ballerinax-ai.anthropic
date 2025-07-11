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

isolated function getExpectedParameterSchema(string message) returns map<json> {
    if message.startsWith("Evaluate this") {
        return expectedParameterSchemaStringForRateBlog6;
    }

    if message.startsWith("Rate this blog") {
        return expectedParameterSchemaStringForRateBlog;
    }

    if message.startsWith("Please rate this blogs") {
        return expectedParameterSchemaStringForRateBlog5;
    }

    if message.startsWith("Please rate this blog") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("What is 1 + 1?") {
        return expectedParameterSchemaStringForRateBlog3;
    }

    if message.startsWith("Tell me") {
        return expectedParameterSchemaStringForRateBlog4;
    }

    if message.startsWith("How would you rate this blog content") {
        return expectedParameterSchemaStringForRateBlog;
    }

    if message.startsWith("How would you rate this text blogs") {
        return expectedParameterSchemaStringForRateBlog5;
    }

    if message.startsWith("How would you rate this text blog") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("How do you rate this blog") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("How would you rate this blog") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("What's the output of the Ballerina code below?") {
        return expectedParamterSchemaStringForBalProgram;
    }

    if message.startsWith("Which country") {
        return expectedParamterSchemaStringForCountry;
    }

    if message.startsWith("Who is a popular sportsperson") {
        return {
            "type": "object",
            "properties": {
                "result": {
                    "oneOf": [
                        {
                            "type": "object",
                            "required": ["firstName", "middleName", "lastName", "yearOfBirth", "sport"],
                            "properties": {
                                "firstName": {"type": "string"},
                                "middleName": {"oneOf": [{"type": "string"}, {"type": "null"}]},
                                "lastName": {"type": "string"},
                                "yearOfBirth": {"type": "integer"},
                                "sport": {"type": "string"}
                            }
                        },
                        {"type": "null"}
                    ]
                }
            }
        };
    }

    return {};
}

isolated function getTheMockLLMResult(string message) returns map<json> {
    if message.startsWith("Evaluate this") {
        return {"result": [9, 1]};
    }

    if message.startsWith("Rate this blog") {
        return {"result": 4};
    }

    if message.startsWith("Please rate this blogs") {
        return {"result": [review, review]};
    }

    if message.startsWith("Please rate this blog") {
        return review;
    }

    if message.startsWith("What is 1 + 1?") {
        return {"result": 2};
    }

    if message.startsWith("Tell me") {
        return {"result": [{"name": "Virat Kohli", "age": 33}, {"name": "Kane Williamson", "age": 30}]};
    }

    if message.startsWith("What's the output of the Ballerina code below?") {
        return {"result": 30};
    }

    if message.startsWith("Which country") {
        return {"result": "Sri Lanka"};
    }

    if message.startsWith("Who is a popular sportsperson") {
        return {"result": {"firstName": "Simone", "middleName": null,
            "lastName": "Biles", "yearOfBirth": 1997, "sport": "Gymnastics"}};
    }

    if message.startsWith("How would you rate this blog content") {
        return {"result": 4};
    }

    if message.startsWith("How do you rate this blog") {
        return {"result": 4};
    }

    if message.startsWith("How would you rate this text blogs") {
        return {"result": [review, review]};
    }

    if message.startsWith("How would you rate this text blog") {
        return review;
    }

    if message.startsWith("How would you rate this blog") {
        return review;
    }

    return {};
}

isolated function getExpectedPrompt(string message) returns string {
    if message.startsWith("Rate this blog") {
        return expectedPromptStringForRateBlog;
    }

    if message.startsWith("Evaluate this") {
        return expectedPromptStringForRateBlog10;
    }

    if message.startsWith("Please rate this blogs") {
        return expectedPromptStringForRateBlog7;
    }

    if message.startsWith("Please rate this blog") {
        return expectedPromptStringForRateBlog2;
    }

    if message.startsWith("What is 1 + 1?") {
        return expectedPromptStringForRateBlog3;
    }

    if message.startsWith("Tell me") {
        return expectedPromptStringForRateBlog4;
    }

    if message.startsWith("How would you rate this blog content") {
        return expectedPromptStringForRateBlog5;
    }

    if message.startsWith("How do you rate this blog") {
        return expectedPromptStringForRateBlog11;
    }

    if message.startsWith("How would you rate this text blogs") {
        return expectedPromptStringForRateBlog9;
    }

    if message.startsWith("How would you rate this text blog") {
        return expectedPromptStringForRateBlog8;
    }

    if message.startsWith("How would you rate this blog") {
        return expectedPromptStringForRateBlog6;
    }

    if message.startsWith("What's the output of the Ballerina code below?") {
        return expectedPromptStringForBalProgram;
    }

    if message.startsWith("Which country") {
        return expectedPromptStringForCountry;
    }

    if message.startsWith("Who is a popular sportsperson") {
        return string `Who is a popular sportsperson that was 
        born in the decade starting from 1990 with Simone in 
        their name?`;
    }

    return "INVALID";
}

isolated function getTestServiceResponse(string content) returns AnthropicApiResponse =>
    {
    id: "test-id",
    model: CLAUDE_3_7_SONNET_20250219,
    'type: "message",
    stop_reason: "tool_calls",
    role: ai:ASSISTANT,
    stop_sequence: (),
    usage: {input_tokens: 130, output_tokens: 34},
    content: [
        {
            'type: "tool_use",
            name: GET_RESULTS_TOOL,
            input: getTheMockLLMResult(content)
        }
    ]
};
