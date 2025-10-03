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

const SERVICE_URL = "http://localhost:8080/llm/anthropic";
const RETRY_SERVICE_URL = "http://localhost:8080/llm/anthropic-retry";
const API_KEY = "not-a-real-api-key";
const ERROR_MESSAGE = "Error occurred while attempting to parse the response from the LLM as the expected type. Retrying and/or validating the prompt could fix the response.";
const RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE = "Runtime schema generation is not yet supported";

final ModelProvider claudeProvider = check new (API_KEY, CLAUDE_3_7_SONNET_20250219, SERVICE_URL);

@test:Config
function testGenerateMethodWithBasicReturnType() returns ai:Error? {
    int|error rating = claudeProvider->generate(`Rate this blog out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, 4);
}

@test:Config
function testGenerateMethodWithBasicArrayReturnType() returns ai:Error? {
    int[]|error rating = claudeProvider->generate(`Evaluate this blogs out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}

        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, [9, 1]);
}

@test:Config
function testGenerateMethodWithRecordReturnType() returns error? {
    Review|error result = claudeProvider->generate(`Please rate this blog out of ${"10"}.
        Title: ${blog2.title}
        Content: ${blog2.content}`);
    test:assertEquals(result, check reviewStr.fromJsonStringWithType(Review));
}

@test:Config
function testGenerateMethodWithTextDocument() returns ai:Error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    int maxScore = 10;

    int|error rating = claudeProvider->generate(`How would you rate this ${"blog"} content out of ${maxScore}. ${blog}.`);
    test:assertEquals(rating, 4);
}

type ReviewArray Review[];

@test:Config
function testGenerateMethodWithTextDocumentArray() returns error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    ai:TextDocument[] blogs = [blog, blog];
    int maxScore = 10;
    Review r = check reviewStr.fromJsonStringWithType(Review);

    ReviewArray|error result = claudeProvider->generate(`How would you rate these text blogs out of ${maxScore}. ${blogs}. Thank you!`);
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithImageDocumentWithBinaryData() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData
    };

    ai:ImageDocument img2 = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };

    string|error description = claudeProvider->generate(`Describe the following image. ${img}.`);
    test:assertTrue(description is error);
    test:assertTrue((<error>description).message().includes("Please specify the mimeType for the image document."));

    description = claudeProvider->generate(`Describe the following image. ${img2}.`);
    test:assertEquals(description, "This is a sample image description.");
}

@test:Config
function testGenerateMethodWithImageDocumentWithUrl() returns ai:Error? {
    ai:ImageDocument img = {
        content: "https://example.com/image.jpg",
        metadata: {
            mimeType: "image/jpg"
        }
    };

    string|error description = claudeProvider->generate(`Describe the image. ${img}.`);
    test:assertEquals(description, "This is a sample image description.");
}

@test:Config
function testFileDocument() returns ai:Error? {
    ai:FileDocument pdf = {
        metadata: {
            mimeType: "application/pdf"
        },
        content: sampleBinaryData
    };

    ai:FileDocument pdf2 = {
        content: sampleBinaryData
    };

    ai:FileDocument pdf3 = {
        content: "https://sampleurl.com"
    };

    ai:FileDocument pdf4 = {
        content: "<invalid-url>"
    };

    ai:FileDocument pdf5 = {
        content: {fileId: "<file-id>"}
    };

    string|error description = claudeProvider->generate(`Describe the following pdf content. ${pdf}.`);
    test:assertEquals(description, "This is a sample pdf description.");

    string[]|error descriptions = claudeProvider->generate(`Describe the following pdf files. ${<ai:FileDocument[]>[pdf, pdf3]}.`);
    test:assertEquals(descriptions, ["This is a sample pdf description.", "This is a sample pdf description."]);

    description = claudeProvider->generate(`Describe the following pdf file. ${pdf5}.`);
    test:assertEquals(description, "This is a sample pdf description.");

    description = claudeProvider->generate(`Describe the following pdf file. ${pdf2}.`);
    if description is string {
        test:assertFail("Expected an error for missing mimeType in the file document.");
    }
    test:assertEquals(description.message(), "Please specify the mimeType for the file document.");

    description = claudeProvider->generate(`Describe the following pdf file. ${pdf4}.`);
    if description is string {
        test:assertFail("Expected an error for invalid URL in the file document.");
    }
    test:assertEquals(description.message(), "Must be a valid URL.");
}

@test:Config
function testUnsupportedAudioDocument() returns ai:Error? {
    ai:AudioDocument audioDoc = {
        content: sampleBinaryData
    };

    string|ai:Error description = claudeProvider->generate(`Describe the following audio file. ${audioDoc}.`);
    if description is string {
        test:assertFail("Expected an error for unsupported document in the file document.");
    }
    test:assertEquals(description.message(), "Only text, image and file documents are supported.");
}

@test:Config
function testGenerateMethodWithImageDocumentWithInvalidUrl() returns ai:Error? {
    ai:ImageDocument img = {
        content: "This-is-not-a-valid-url"
    };

    string|ai:Error description = claudeProvider->generate(`Please describe the image. ${img}.`);
    test:assertTrue(description is ai:Error);

    string actualErrorMessage = (<ai:Error>description).message();
    string expectedErrorMessage = "Must be a valid URL";
    test:assertTrue((<ai:Error>description).message().includes("Must be a valid URL"),
            string `expected '${expectedErrorMessage}', found ${actualErrorMessage}`);
}

@test:Config
function testGenerateMethodWithImageDocumentArray() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:ImageDocument img2 = {
        content: "https://example.com/image.jpg"
    };

    string[]|error descriptions = claudeProvider->generate(
        `Describe the following ${"2"} images. ${<ai:ImageDocument[]>[img, img2]}.`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample image description."]);
}

@test:Config
function testGenerateMethodWithTextAndImageDocumentArray() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };

    string[]|error descriptions = claudeProvider->generate(
        `Please describe the following image and the doc. ${<ai:Document[]>[img, blog]}.`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample doc description."]);
}

@test:Config
function testGenerateMethodWithImageDocumentsandTextDocuments() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };

    string[]|error descriptions = claudeProvider->generate(
        `${"Describe"} the following ${"text"} ${"document"} and image document. ${img}${blog}`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample doc description."]);
}

@test:Config
function testGenerateMethodWithUnsupportedDocument() returns ai:Error? {
    ai:Document doc = {
        'type: "audio",
        content: "dummy-data"
    };

    string[]|error descriptions = claudeProvider->generate(`What is the content in this document. ${doc}.`);
    test:assertTrue(descriptions is error);
    test:assertTrue((<error>descriptions).message().includes("Only text, image and file documents are supported."));
}

@test:Config
function testGenerateMethodWithRecordArrayReturnType() returns error? {
    int maxScore = 10;
    Review r = check reviewStr.fromJsonStringWithType(Review);

    ReviewArray|error result = claudeProvider->generate(`Please rate this blogs out of ${maxScore}.
        [{Title: ${blog1.title}, Content: ${blog1.content}}, {Title: ${blog2.title}, Content: ${blog2.content}}]`);
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithInvalidBasicType() returns ai:Error? {
    boolean|error rating = claudeProvider->generate(`What is ${1} + ${1}?`);
    test:assertTrue(rating is error);
    test:assertTrue((<error>rating).message().includes(ERROR_MESSAGE));
}

type ProductName record {|
    string name;
|};

@test:Config
function testGenerateMethodWithInvalidRecordType() {
    ProductName[]|map<string>|error rating = claudeProvider->generate(
                `Tell me name and the age of the top 10 world class cricketers`);
    string msg = (<error>rating).message();
    test:assertTrue(rating is error);
    test:assertTrue(msg.includes(RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE),
        string `expected error message to contain: ${RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE}, but found ${msg}`);
}

type ProductNameArray ProductName[];

@test:Config
function testGenerateMethodWithInvalidRecordArrayType2() returns ai:Error? {
    ProductNameArray|error rating = claudeProvider->generate(
                `Tell me name and the age of the top 10 world class cricketers`);
    test:assertTrue(rating is error);
    test:assertTrue((<error>rating).message().includes(ERROR_MESSAGE));
}

type Cricketers record {|
    string name;
|};

type Cricketers1 record {|
    string name;
|};

type Cricketers2 record {|
    string name;
|};

type Cricketers3 record {|
    string name;
|};

type Cricketers4 record {|
    string name;
|};

type Cricketers5 record {|
    string name;
|};

type Cricketers6 record {|
    string name;
|};

type Cricketers7 record {|
    string name;
|};

type Cricketers8 record {|
    string name;
|};

@test:Config
function testGenerateMethodWithStringUnionNull() returns error? {
    string? result = check claudeProvider->generate(`Give me a random joke`);
    test:assertTrue(result is string);
}

@test:Config
function testGenerateMethodWithRecUnionBasicType() returns error? {
    Cricketers|string result = check claudeProvider->generate(`Give me a random joke about cricketers`);
    test:assertTrue(result is string);
}

@test:Config
function testGenerateMethodWithRecUnionNull() returns error? {
    Cricketers1? result = check claudeProvider->generate(`Name a random world class cricketer in India`);
    test:assertTrue(result is Cricketers1);
}

@test:Config
function testGenerateMethodWithArrayOnly() returns error? {
    Cricketers2[] result = check claudeProvider->generate(`Name 10 world class cricketers in India`);
    test:assertTrue(result is Cricketers2[]);
}

@test:Config
function testGenerateMethodWithArrayUnionBasicType() returns error? {
    Cricketers3[]|string result = check claudeProvider->generate(`Name 10 world class cricketers as string`);
    test:assertTrue(result is Cricketers3[]);
}


@test:Config
function testGenerateMethodWithArrayUnionNull() returns error? {
    Cricketers4[]? result = check claudeProvider->generate(`Name 10 world class cricketers`);
    test:assertTrue(result is Cricketers4[]);
}

@test:Config
function testGenerateMethodWithArrayUnionRecord() returns ai:Error? {
    Cricketers5[]|Cricketers6|error result = claudeProvider->generate(`Name top 10 world class cricketers`);
    test:assertTrue(result is Cricketers5[]);
}

@test:Config
function testGenerateMethodWithArrayUnionRecord2() returns ai:Error? {
   Cricketers7[]|Cricketers8|error result = claudeProvider->generate(`Name a random world class cricketer`);
    test:assertTrue(result is Cricketers8);
}

@test:Config
function testGenerateWithValidRetryConfig() returns error? {
    final ModelProvider modelProvider =
        check new (API_KEY, CLAUDE_3_7_SONNET_20250219, RETRY_SERVICE_URL, generatorConfig = {retryConfig: {count: 2, interval: 2}});

    int|ai:Error rating = modelProvider->generate(`What is the result of ${1} + ${1}?`);
    test:assertEquals(rating, 2, "Failed with valid retry config {count: 2, interval: 2}");
}

@test:Config
function testGenerateWithDefaultRetryInterval() returns error? {
    final ModelProvider modelProvider =
        check new (API_KEY, CLAUDE_3_7_SONNET_20250219, RETRY_SERVICE_URL, generatorConfig = {retryConfig: {count: 2}});

    int|ai:Error rating = modelProvider->generate(`What is the result of 1 + 2?`);
    test:assertEquals(rating, 3, "Failed with retry config {count: 2}");
}

@test:Config
function testGenerateWithSingleRetry() returns error? {
    final ModelProvider modelProvider =
        check new (API_KEY, CLAUDE_3_7_SONNET_20250219, RETRY_SERVICE_URL, generatorConfig = {retryConfig: {count: 1}});

    int|ai:Error rating = modelProvider->generate(`What is the result of 1 + 3?`);
    test:assertEquals(rating, 4, "Failed with retry config {count: 1}");
}

@test:Config
function testGenerateWithEmptyRetryConfig() returns error? {
    final ModelProvider modelProvider =
        check new (API_KEY, CLAUDE_3_7_SONNET_20250219, RETRY_SERVICE_URL, generatorConfig = {retryConfig: {}});

    int|ai:Error rating = modelProvider->generate(`What is the result of 1 + 4?`);
    test:assertEquals(rating, 5, "Failed with empty retry config {}");
}

@test:Config
function testGenerateFailsWithInvalidNegativeRetryCount() returns error? {
    final ModelProvider modelProvider =
        check new (API_KEY, CLAUDE_3_7_SONNET_20250219, RETRY_SERVICE_URL, generatorConfig = {retryConfig: {count: -1}});

    int|ai:Error rating = modelProvider->generate(`What is the result of ${1} + ${6}?`);
    test:assertTrue(rating is error, "Expected an error for negative retry count");
    if rating is error {
        test:assertEquals(rating.message(), "Invalid retry count: -1");
    }
}

@test:Config
function testGenerateFailsWithInvalidNegativeRetryInterval() returns error? {
    final ModelProvider modelProvider =
        check new (API_KEY, CLAUDE_3_7_SONNET_20250219, RETRY_SERVICE_URL, generatorConfig = {retryConfig: {count: 4, interval: -1}});

    int|ai:Error rating = modelProvider->generate(`What is the result of ${1} + ${6}?`);
    test:assertTrue(rating is error, "Expected an error for negative retry interval");
    if rating is error {
        test:assertEquals(rating.message(), "Invalid retry interval: -1");
    }
}
