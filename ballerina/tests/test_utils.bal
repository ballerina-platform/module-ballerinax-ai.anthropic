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

    if message.startsWith("What is") {
        return expectedParameterSchemaStringForRateBlog3;
    }

    if message.startsWith("Tell me") {
        return expectedParameterSchemaStringForRateBlog4;
    }

    if message.startsWith("How would you rate these text blogs") {
        return expectedParameterSchemaStringForRateBlog5;
    }

    if message.startsWith("How would you rate this text blog") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("How would you rate this") {
        return expectedParameterSchemaStringForRateBlog;
    }

    if message.startsWith("Which country") {
        return expectedParamterSchemaStringForCountry;
    }

    if message.startsWith("Describe the following 2 images") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("Please describe the following image and the doc") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("Describe the following text document and image document") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("What is the content in this document") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("Describe the following image") {
        return expectedParameterSchemaStringForRateBlog8;
    }

    if message.startsWith("Describe the image") {
        return expectedParameterSchemaStringForRateBlog8;
    }

    if message.startsWith("Describe the following pdf content") {
        return expectedParameterSchemaStringForRateBlog8;
    }

    if message.startsWith("Describe the following pdf files") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("Describe the following pdf file") {
        return expectedParameterSchemaStringForRateBlog8;
    }

    if message.startsWith("Please describe the image") {
        return expectedParameterSchemaStringForRateBlog8;
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

    if message.startsWith("Give me a random joke about cricketers") {
        return expectedParameterSchemaForRecUnionBasicType;
    }

    if message.startsWith("Give me a random joke") {
        return {"type":"object","properties":{"result":{"anyOf":[{"type":"string"},{"type":"null"}]}}};
    }

    if message.startsWith("Name a random world class cricketer in India") {
        return expectedParameterSchemaForRecUnionNull;
    }

    if message.startsWith("Name 10 world class cricketers in India") {
        return expectedParameterSchemaForArrayOnly;
    }

    if message.startsWith("Name 10 world class cricketers as string") {
        return expectedParameterSchemaForArrayUnionBasicType;
    }

    if message.startsWith("Name top 10 world class cricketers") {
        return expectedParameterSchemaForArrayUnionRec;
    }

    if message.startsWith("Name a random world class cricketer") {
        return expectedParameterSchemaForArrayUnionRec;
    }

    if message.startsWith("Name 10 world class cricketers") {
        return expectedParamSchemaForArrayUnionNull;
    }

    return {};
}

isolated function getTheMockLLMResult(string message) returns map<json> {
    if message.startsWith("Evaluate this") {
        return {result: [9, 1]};
    }

    if message.startsWith("Rate this blog") {
        return {result: 4};
    }

    if message.startsWith("Please rate this blogs") {
        return {result: [review, review]};
    }

    if message.startsWith("Please rate this blog") {
        return review;
    }

    if message.startsWith("What is") {
        return {result: 2};
    }

    if message.startsWith("Tell me") {
        return {result: [{name: "Virat Kohli", age: 33}, {name: "Kane Williamson", age: 30}]};
    }

    if message.startsWith("Which country") {
        return {result: "Sri Lanka"};
    }

    if message.startsWith("Who is a popular sportsperson") {
        return {result: {firstName: "Simone", middleName: null, 
            lastName: "Biles", yearOfBirth: 1997, sport: "Gymnastics"}};
    }

    if message.startsWith("How would you rate these text blogs") {
        return {"result": [review, review]};
    }

    if message.startsWith("How would you rate this text blog") {
        return review;
    }

    if message.startsWith("How would you rate this") {
        return {result: 4};
    }

    if message.startsWith("Describe the following 2 images") {
        return {result: ["This is a sample image description.", "This is a sample image description."]};
    }

    if message.startsWith("Please describe the following image and the doc") {
        return {result: ["This is a sample image description.", "This is a sample doc description."]};
    }

    if message.startsWith("Describe the following text document and image document") {
        return {result: ["This is a sample image description.", "This is a sample doc description."]};
    }

    if message.startsWith("What is the content in this document") {
        return {result: ["This is a sample image description."]};
    }

    if message.startsWith("Describe the following image") {
        return {result: "This is a sample image description."};
    }

    if message.startsWith("Describe the image") {
        return {result: "This is a sample image description."};
    }

    if message.startsWith("Please describe the image") {
        return {result: "This is a sample image description."};
    }

    if message.startsWith("Describe the following pdf content") {
        return {result: "This is a sample pdf description."};
    }

    if message.startsWith("Describe the following pdf files") {
        return {result: ["This is a sample pdf description.", "This is a sample pdf description."]};
    }

    if message.startsWith("Describe the following pdf file") {
        return {result: "This is a sample pdf description."};
    }

    if message.startsWith("Name a random world class cricketer in India") {
        return {"result": {"name": "Sanga"}};
    }

    if message.startsWith("Name a random world class cricketer") {
        return {"result": {"name": "Sanga"}};
    }

    if message.startsWith("Name 10 world class cricketers") {
        return {
            "result": [
                {"name": "Virat Kohli"},
                {"name": "Joe Root"},
                {"name": "Steve Smith"},
                {"name": "Kane Williamson"},
                {"name": "Babar Azam"},
                {"name": "Ben Stokes"},
                {"name": "Jasprit Bumrah"},
                {"name": "Pat Cummins"},
                {"name": "Shaheen Afridi"},
                {"name": "Rashid Khan"}
            ]
        };
    }

    if message.startsWith("Name top 10 world class cricketers") {
        return {
            "result": [
                {"name": "Virat Kohli"},
                {"name": "Joe Root"},
                {"name": "Steve Smith"},
                {"name": "Kane Williamson"},
                {"name": "Babar Azam"},
                {"name": "Ben Stokes"},
                {"name": "Jasprit Bumrah"},
                {"name": "Pat Cummins"},
                {"name": "Shaheen Afridi"},
                {"name": "Rashid Khan"}
            ]
        };
    }

    if message.startsWith("Give me a random joke") {
        return {"result": "This is a random joke"};
    }

    return {};
}

isolated function getExpectedContentParts(string message) returns (map<anydata>)[] {
    if message.startsWith("Rate this blog") {
        return expectedContentPartsForRateBlog;
    }

    if message.startsWith("Evaluate this") {
        return expectedContentPartsForRateBlog10;
    }

    if message.startsWith("Please rate this blogs") {
        return expectedContentPartsForRateBlog7;
    }

    if message.startsWith("Please rate this blog") {
        return expectedContentPartsForRateBlog2;
    }

    if message.startsWith("What is") {
        return expectedContentPartsForRateBlog3;
    }

    if message.startsWith("Tell me") {
        return expectedContentPartsForRateBlog4;
    }

    if message.startsWith("How would you rate these text blogs") {
        return expectedContentPartsForRateBlog9;
    }

    if message.startsWith("How would you rate this text blog") {
        return expectedContentPartsForRateBlog8;
    }

    if message.startsWith("How would you rate this") {
        return expectedContentPartsForRateBlog5;
    }

    if message.startsWith("Which country") {
        return expectedContentPartsForCountry;
    }

    if message.startsWith("Who is a popular sportsperson") {
        return [
            {
                "type": "text",
                "text": string `Who is a popular sportsperson that was 
                    born in the decade starting from 1990 with Simone in 
                    their name?`
            }
        ];
    }

    if message.startsWith("Describe the following 2 images") {
        return [
            {"type": "text", "text": "Describe the following 2 images. "},
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/png",
                    "data": sampleBase64Str
                }
            },
            {
                "type": "image",
                "source": {
                    "type": "url",
                    "url": sampleImageUrl
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Please describe the following image and the doc") {
        return [
            {"type": "text", "text": "Please describe the following image and the doc. "},
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/png",
                    "data": sampleBase64Str
                }
            },
            {
                "type": "text",
                "text": string `Title: ${blog1.title} Content: ${blog1.content}`
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Describe the following text document and image document") {
        return [
            {"type": "text", "text": "Describe the following text document and image document. "},
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/png",
                    "data": sampleBase64Str
                }
            },
            {
                "type": "text",
                "text": string `Title: ${blog1.title} Content: ${blog1.content}`
            }
        ];
    }

    if message.startsWith("Describe the following image") {
        return [
            {"type": "text", "text": "Describe the following image. "},
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/png",
                    "data": sampleBase64Str
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Describe the image") {
        return [
            {"type": "text", "text": "Describe the image. "},
            {
                "type": "image",
                "source": {
                    "type": "url",
                    "url": sampleImageUrl
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Please describe the image") {
        return [
            {"type": "text", "text": "Please describe the image. "},
            {
                "type": "image",
                "source": {
                    "type": "url",
                    "data": "This-is-not-a-valid-url"
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Describe the following pdf content") {
        return [
            {"type": "text", "text": "Describe the following pdf content. "},
            {
                "type": "document",
                "source": {
                    "type": "base64",
                    "media_type": "application/pdf",
                    "data": sampleBase64Str
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Describe the following pdf files") {
        return [
            {"type": "text", "text": "Describe the following pdf files. "},
            {
                "type": "document",
                "source": {
                    "type": "base64",
                    "media_type": "application/pdf",
                    "data": sampleBase64Str
                }
            },
            {
                "type": "document",
                "source": {
                    "type": "url",
                    "url": "https://sampleurl.com"
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Describe the following pdf file") {
        return [
            {"type": "text", "text": "Describe the following pdf file. "},
            {
                "type": "document",
                "source": {
                    "type": "file",
                    "file_id": "<file-id>"
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Name 10 world class cricketers in India") {
        return [{"type": "text", "text": "Name 10 world class cricketers in India"}];
    }

    if message.startsWith("Name 10 world class cricketers as string") {
        return [{"type": "text", "text": "Name 10 world class cricketers as string"}];
    }

    if message.startsWith("Name 10 world class cricketers") {
        return [{"type": "text", "text": "Name 10 world class cricketers"}];
    }

    if message.startsWith("Name top 10 world class cricketers") {
        return [{"type": "text", "text": "Name top 10 world class cricketers"}];
    }

    if message.startsWith("Name a random world class cricketer in India") {
        return [{"type": "text", "text": "Name a random world class cricketer in India"}];
    }

    if message.startsWith("Name a random world class cricketer") {
        return [{"type": "text", "text": "Name a random world class cricketer"}];
    }

    if message.startsWith("Give me a random joke about cricketers") {
        return [{"type": "text", "text": "Give me a random joke about cricketers"}];
    }

    if message.startsWith("Give me a random joke") {
        return [{"type": "text", "text": "Give me a random joke"}];
    }

    return [
        {
            "type": "text",
            "text": "INVALID"
        }
    ];
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
