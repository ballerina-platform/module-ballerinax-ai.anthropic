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
import ballerina/io;
import ballerina/test;

const TOKEN_SERVICE_URL = "http://localhost:8080/llm/anthropic/oauth";
const FEDERATION_RULE_ID = "fdrl_test";
const ORGANIZATION_ID = "00000000-0000-0000-0000-000000000000";
const SERVICE_ACCOUNT_ID = "svac_test";
const WORKSPACE_ID = "wrkspc_test";

isolated function getCapturedHeader(string testId, string method, string header) returns string?|error {
    json value;
    lock {
        value = capturedRequests[string `${testId}:${method}:${header}`].clone();
    }
    return value.ensureType();
}

isolated function getTokenExchangeRequests(string testId) returns map<json>[] {
    lock {
        return (tokenExchangeRequests[testId] ?: []).clone();
    }
}

// Returns the token URL of the mock token endpoint. With `failAfter` > 0, exchanges after the first `failAfter`
// fail; with -1, every exchange fails.
function tokenUrl(string testId, int expiresIn = 3600, int failAfter = 0) returns string =>
    string `${TOKEN_SERVICE_URL}/${testId}/${expiresIn}/${failAfter}/token`;

function callChatAndGenerate(ModelProvider provider) returns error? {
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
}

@test:Config
function testApiKeyAuth() returns error? {
    string testId = "auth-api-key";
    ModelProvider provider = check new ({apiKey: API_KEY}, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);
    foreach string method in ["chat", "generate"] {
        test:assertEquals(check getCapturedHeader(testId, method, "x-api-key"), API_KEY);
        test:assertEquals(check getCapturedHeader(testId, method, "authorization"), ());
        test:assertEquals(check getCapturedHeader(testId, method, "anthropic-workspace-id"), ());
    }
}

@test:Config
function testApiKeyAuthWithWorkspaceId() returns error? {
    string testId = "auth-api-key-workspace";
    ModelProvider provider = check new ({apiKey: API_KEY, workspaceId: WORKSPACE_ID}, CLAUDE_SONNET_4_6,
        string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);
    foreach string method in ["chat", "generate"] {
        test:assertEquals(check getCapturedHeader(testId, method, "x-api-key"), API_KEY);
        test:assertEquals(check getCapturedHeader(testId, method, "anthropic-workspace-id"), WORKSPACE_ID);
    }
}

@test:Config
function testBearerTokenAuth() returns error? {
    string testId = "auth-bearer-token";
    ModelProvider provider = check new ({token: "sk-ant-oat01-test"}, CLAUDE_SONNET_4_6,
        string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);
    foreach string method in ["chat", "generate"] {
        test:assertEquals(check getCapturedHeader(testId, method, "authorization"), "Bearer sk-ant-oat01-test");
        test:assertEquals(check getCapturedHeader(testId, method, "x-api-key"), ());
    }
}

@test:Config
function testWorkloadIdentityAuth() returns error? {
    string testId = "auth-wif";
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        serviceAccountId: SERVICE_ACCOUNT_ID,
        workspaceId: WORKSPACE_ID,
        identityToken: " jwt-static\n",
        tokenUrl: tokenUrl(testId)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);

    // The access token is cached, so both requests use the same exchange.
    map<json>[] exchanges = getTokenExchangeRequests(testId);
    test:assertEquals(exchanges.length(), 1);
    test:assertEquals(exchanges[0], {
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: "jwt-static",
        federation_rule_id: FEDERATION_RULE_ID,
        organization_id: ORGANIZATION_ID,
        service_account_id: SERVICE_ACCOUNT_ID,
        workspace_id: WORKSPACE_ID
    });
    foreach string method in ["chat", "generate"] {
        test:assertEquals(check getCapturedHeader(testId, method, "authorization"), "Bearer access-1");
        test:assertEquals(check getCapturedHeader(testId, method, "x-api-key"), ());
        // The workspace is selected at token exchange, so it is not sent as a header.
        test:assertEquals(check getCapturedHeader(testId, method, "anthropic-workspace-id"), ());
    }
}

@test:Config
function testWorkloadIdentityAuthWithoutWorkspaceId() returns error? {
    string testId = "auth-wif-no-workspace";
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        serviceAccountId: SERVICE_ACCOUNT_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    test:assertFalse(getTokenExchangeRequests(testId)[0].hasKey("workspace_id"));
}

@test:Config
function testWorkloadIdentityAuthRefreshesAccessTokenBeforeExpiry() returns error? {
    string testId = "auth-wif-refresh";
    // An access token that expires within the refresh buffer is exchanged again on the next request.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        serviceAccountId: SERVICE_ACCOUNT_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, expiresIn = 100)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);
    test:assertEquals(getTokenExchangeRequests(testId).length(), 2);
    test:assertEquals(check getCapturedHeader(testId, "chat", "authorization"), "Bearer access-1");
    test:assertEquals(check getCapturedHeader(testId, "generate", "authorization"), "Bearer access-2");
}

@test:Config
function testWorkloadIdentityAuthReadsIdentityTokenFileForEveryExchange() returns error? {
    string testId = "auth-wif-file";
    string path = "target/wif-identity-token.txt";
    check io:fileWriteString(path, "jwt-from-file-1\n");
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        serviceAccountId: SERVICE_ACCOUNT_ID,
        identityToken: {path},
        tokenUrl: tokenUrl(testId, expiresIn = 100)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    // The identity token rotates on disk.
    check io:fileWriteString(path, "jwt-from-file-2\n");
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);

    map<json>[] exchanges = getTokenExchangeRequests(testId);
    test:assertEquals(exchanges.length(), 2);
    test:assertEquals(exchanges[0]["assertion"], "jwt-from-file-1");
    test:assertEquals(exchanges[1]["assertion"], "jwt-from-file-2");
}

isolated int identityTokenProviderCalls = 0;

@test:Config
function testWorkloadIdentityAuthCallsIdentityTokenProviderForEveryExchange() returns error? {
    string testId = "auth-wif-provider";
    IdentityTokenProvider identityTokenProvider = isolated function() returns string|error {
        lock {
            identityTokenProviderCalls += 1;
            return string `jwt-from-provider-${identityTokenProviderCalls}`;
        }
    };
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        serviceAccountId: SERVICE_ACCOUNT_ID,
        identityToken: identityTokenProvider,
        tokenUrl: tokenUrl(testId, expiresIn = 100)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);

    map<json>[] exchanges = getTokenExchangeRequests(testId);
    test:assertEquals(exchanges.length(), 2);
    test:assertEquals(exchanges[0]["assertion"], "jwt-from-provider-1");
    test:assertEquals(exchanges[1]["assertion"], "jwt-from-provider-2");
}

@test:Config
function testWorkloadIdentityAuthUsesCachedAccessTokenWhenRefreshFails() returns error? {
    string testId = "auth-wif-refresh-fails";
    // The first exchange succeeds and the rest fail. The access token is still valid for longer than the
    // expiry buffer, so it is used after the refresh fails.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        serviceAccountId: SERVICE_ACCOUNT_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, expiresIn = 100, failAfter = 1)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);
    test:assertEquals(getTokenExchangeRequests(testId).length(), 2);
    test:assertEquals(check getCapturedHeader(testId, "generate", "authorization"), "Bearer access-1");
}

@test:Config
function testWorkloadIdentityAuthReturnsErrorWhenExchangeFails() returns error? {
    string testId = "auth-wif-fails";
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        serviceAccountId: SERVICE_ACCOUNT_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, failAfter = -1)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);

    ai:ChatAssistantMessage|ai:Error chatResult = provider->chat([{role: ai:USER, content: "Hi"}]);
    if chatResult !is ai:LlmError {
        test:assertFail("Expected an ai:LlmError from chat");
    }
    test:assertTrue(chatResult.message().startsWith("Workload Identity Federation token exchange failed with status 401"));

    int|ai:Error generateResult = provider->generate(`Pick a number`);
    if generateResult !is ai:LlmError {
        test:assertFail("Expected an ai:LlmError from generate");
    }
}

@test:Config
function testWorkloadIdentityAuthReturnsErrorWhenIdentityTokenFileIsMissing() returns error? {
    string testId = "auth-wif-missing-file";
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        serviceAccountId: SERVICE_ACCOUNT_ID,
        identityToken: {path: "target/does-not-exist.txt"},
        tokenUrl: tokenUrl(testId)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    ai:ChatAssistantMessage|ai:Error result = provider->chat([{role: ai:USER, content: "Hi"}]);
    if result !is ai:Error {
        test:assertFail("Expected an ai:Error");
    }
    test:assertEquals(result.message(), "Failed to get the identity token for Workload Identity Federation");
    test:assertEquals(getTokenExchangeRequests(testId).length(), 0);
}
