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
import ballerina/lang.runtime;
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
// fail; with -1, every exchange fails. With `failDelay`, a failing exchange responds after that many seconds.
// A failing exchange returns a 401, or a 503 with `unavailable`.
function tokenUrl(string testId, int expiresIn = 3600, int failAfter = 0, decimal? failDelay = (),
        boolean unavailable = false) returns string {
    string url = string `${TOKEN_SERVICE_URL}/${testId}/${expiresIn}/${failAfter}/token?unavailable=${unavailable}`;
    return failDelay is () ? url : string `${url}&failDelay=${failDelay}`;
}

function chatConcurrently(ModelProvider provider, int count) returns (ai:ChatAssistantMessage|ai:Error)[] {
    future<ai:ChatAssistantMessage|ai:Error>[] calls = [];
    foreach int i in 0 ..< count {
        future<ai:ChatAssistantMessage|ai:Error> call = start provider->chat([{role: ai:USER, content: "Hi"}]);
        calls.push(call);
    }
    (ai:ChatAssistantMessage|ai:Error)[] results = [];
    foreach future<ai:ChatAssistantMessage|ai:Error> call in calls {
        ai:ChatAssistantMessage|ai:Error result = wait call;
        results.push(result);
    }
    return results;
}

function callChatAndGenerate(ModelProvider provider) returns error? {
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    int _ = check provider->generate(`Pick a number`);
}

@test:Config
function testStringApiKeyAuth() returns error? {
    string testId = "auth-string-api-key";
    ModelProvider provider = check new (API_KEY, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);
    // A string key is sent in `x-api-key`, as in 1.x.
    foreach string method in ["chat", "generate"] {
        test:assertEquals(check getCapturedHeader(testId, method, "x-api-key"), API_KEY);
        test:assertEquals(check getCapturedHeader(testId, method, "authorization"), ());
        test:assertEquals(check getCapturedHeader(testId, method, "anthropic-workspace-id"), ());
    }
}

@test:Config
function testStringApiKeyAuthAsNamedArgument() returns error? {
    string testId = "auth-string-api-key-named";
    ModelProvider provider = check new (apiKey = API_KEY, modelType = CLAUDE_SONNET_4_6,
        serviceUrl = string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);
    foreach string method in ["chat", "generate"] {
        test:assertEquals(check getCapturedHeader(testId, method, "x-api-key"), API_KEY);
        test:assertEquals(check getCapturedHeader(testId, method, "authorization"), ());
        test:assertEquals(check getCapturedHeader(testId, method, "anthropic-workspace-id"), ());
    }
}

@test:Config
function testApiKeyIsTrimmed() returns error? {
    string testId = "auth-api-key-trimmed";
    // A key read from a file or an environment variable may end with a newline.
    ModelProvider stringProvider = check new (string ` ${API_KEY}${"\n"}`, CLAUDE_SONNET_4_6,
        string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check stringProvider->chat([{role: ai:USER, content: "Hi"}]);
    test:assertEquals(check getCapturedHeader(testId, "chat", "x-api-key"), API_KEY);

    ModelProvider configProvider = check new ({apiKey: string `${API_KEY}${"\n"}`}, CLAUDE_SONNET_4_6,
        string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check configProvider->chat([{role: ai:USER, content: "Hi"}]);
    test:assertEquals(check getCapturedHeader(testId, "chat", "authorization"), string `Bearer ${API_KEY}`);
}

@test:Config
function testEmptyApiKeyFails() {
    foreach string|ApiKeyConfig apiKey in ["", " \n", {apiKey: ""}] {
        ModelProvider|ai:Error provider = new (apiKey, CLAUDE_SONNET_4_6);
        if provider !is ai:Error {
            test:assertFail("Expected an ai:Error for an empty API key");
        }
        test:assertEquals(provider.message(), "The Anthropic API key is empty");
    }
}

@test:Config
function testApiKeyAuth() returns error? {
    string testId = "auth-api-key";
    ModelProvider provider = check new ({apiKey: API_KEY}, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);
    foreach string method in ["chat", "generate"] {
        test:assertEquals(check getCapturedHeader(testId, method, "authorization"), string `Bearer ${API_KEY}`);
        test:assertEquals(check getCapturedHeader(testId, method, "x-api-key"), ());
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
        test:assertEquals(check getCapturedHeader(testId, method, "authorization"), string `Bearer ${API_KEY}`);
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
function testWorkloadIdentityAuthWithoutServiceAccountId() returns error? {
    string testId = "auth-wif-no-service-account";
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    test:assertFalse(getTokenExchangeRequests(testId)[0].hasKey("service_account_id"));
}

@test:Config
function testWorkloadIdentityAuthDefaultsTokenUrlToServiceUrl() returns error? {
    string testId = "auth-wif-default-token-url";
    // Without `tokenUrl`, the exchange goes to `/oauth/token` under the service URL, not to api.anthropic.com.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        identityToken: "jwt-static"
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    test:assertEquals(getTokenExchangeRequests(testId).length(), 1);
    test:assertEquals(check getCapturedHeader(testId, "chat", "authorization"), "Bearer access-1");
}

@test:Config
function testWorkloadIdentityAuthConcurrentRequestsExchangeOnce() returns error? {
    string testId = "auth-wif-concurrent";
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    future<ai:ChatAssistantMessage|ai:Error>[] calls = [];
    foreach int i in 0 ..< 10 {
        future<ai:ChatAssistantMessage|ai:Error> call = start provider->chat([{role: ai:USER, content: "Hi"}]);
        calls.push(call);
    }
    foreach future<ai:ChatAssistantMessage|ai:Error> call in calls {
        _ = check wait call;
    }
    test:assertEquals(getTokenExchangeRequests(testId).length(), 1);
}

@test:Config
function testWorkloadIdentityAuthReusesShortLivedAccessToken() returns error? {
    string testId = "auth-wif-short-lived";
    // A 100-second access token is inside the 120-second refresh buffer from the start. It is refreshed halfway
    // through its lifetime instead, so back-to-back requests share one exchange.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, expiresIn = 100)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    check callChatAndGenerate(provider);
    test:assertEquals(getTokenExchangeRequests(testId).length(), 1);
}

@test:Config
function testWorkloadIdentityAuthRefreshesAccessTokenBeforeExpiry() returns error? {
    string testId = "auth-wif-refresh";
    // A 6-second access token is refreshed after 3 seconds, halfway through its lifetime.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, expiresIn = 6)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    runtime:sleep(3.5);
    int _ = check provider->generate(`Pick a number`);
    test:assertEquals(getTokenExchangeRequests(testId).length(), 2);
    test:assertEquals(check getCapturedHeader(testId, "chat", "authorization"), "Bearer access-1");
    test:assertEquals(check getCapturedHeader(testId, "generate", "authorization"), "Bearer access-2");
}

@test:Config
function testWorkloadIdentityAuthUsesCachedAccessTokenWhenRefreshFails() returns error? {
    string testId = "auth-wif-refresh-fails";
    // A 6-second access token is refreshed after 3 seconds, and used until 4.5 seconds if the refresh fails.
    // The first exchange succeeds and the rest fail, so the request at 3.5 seconds uses the cached token.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, expiresIn = 6, failAfter = 1)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    runtime:sleep(3.5);
    int _ = check provider->generate(`Pick a number`);
    test:assertEquals(getTokenExchangeRequests(testId).length(), 2);
    test:assertEquals(check getCapturedHeader(testId, "generate", "authorization"), "Bearer access-1");
}

@test:Config
function testWorkloadIdentityAuthRechecksExpiryAfterRefreshFails() returns error? {
    string testId = "auth-wif-refresh-fails-slowly";
    // A 6-second access token may be used until 4.5 seconds if a refresh fails. The refresh starts at 3.5 seconds
    // and fails 2 seconds later, after that point, so the cached token must not be used.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, expiresIn = 6, failAfter = 1, failDelay = 2)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    runtime:sleep(3.5);
    ai:ChatAssistantMessage|ai:Error result = provider->chat([{role: ai:USER, content: "Hi"}]);
    if result !is ai:LlmError {
        test:assertFail("Expected an ai:LlmError once the access token is inside the expiry buffer");
    }
    test:assertEquals(getTokenExchangeRequests(testId).length(), 2);
}

@test:Config
function testWorkloadIdentityAuthDoesNotRetryTokenExchange() returns error? {
    string testId = "auth-wif-no-retry";
    // Retrying the exchange would send the same identity token again, which Anthropic rejects when the identity
    // token has a `jti` claim. The retry configuration applies only to requests to the Anthropic API.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        serviceAccountId: SERVICE_ACCOUNT_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, failAfter = -1)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`,
        retryConfig = {count: 3, interval: 0.1, statusCodes: [401]});
    ai:ChatAssistantMessage|ai:Error result = provider->chat([{role: ai:USER, content: "Hi"}]);
    if result !is ai:LlmError {
        test:assertFail("Expected an ai:LlmError");
    }
    test:assertEquals(getTokenExchangeRequests(testId).length(), 1);
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
function testWorkloadIdentityAuthStopsExchangingAfterRejection() returns error? {
    string testId = "auth-wif-rejected";
    // A rejected identity token cannot succeed later, so concurrent and later requests return the same error
    // without calling the token endpoint again.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, failAfter = -1, failDelay = 0.5)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    foreach ai:ChatAssistantMessage|ai:Error result in chatConcurrently(provider, 10) {
        if result !is ai:LlmError {
            test:assertFail("Expected an ai:LlmError");
        }
        test:assertTrue(result.message().includes("Create a new model provider with a new identity token"),
            result.message());
    }
    runtime:sleep(5.5);
    int|ai:Error later = provider->generate(`Pick a number`);
    if later !is ai:LlmError {
        test:assertFail("Expected an ai:LlmError after the backoff period");
    }
    test:assertEquals(getTokenExchangeRequests(testId).length(), 1);
}

@test:Config
function testWorkloadIdentityAuthBacksOffAfterFailedRefresh() returns error? {
    string testId = "auth-wif-backoff";
    // An 8-second access token is refreshed after 4 seconds, and used until 6 seconds if the refresh fails. The
    // token endpoint is unavailable after the first exchange and takes 0.5 seconds to fail.
    ModelProvider provider = check new ({
        federationRuleId: FEDERATION_RULE_ID,
        organizationId: ORGANIZATION_ID,
        identityToken: "jwt-static",
        tokenUrl: tokenUrl(testId, expiresIn = 8, failAfter = 1, failDelay = 0.5, unavailable = true)
    }, CLAUDE_SONNET_4_6, string `${CAPTURE_SERVICE_URL}/${testId}`);
    _ = check provider->chat([{role: ai:USER, content: "Hi"}]);
    runtime:sleep(4.2);
    // Concurrent requests in the refresh window make one failed refresh between them and use the cached token.
    foreach ai:ChatAssistantMessage|ai:Error result in chatConcurrently(provider, 10) {
        _ = check result;
    }
    test:assertEquals(getTokenExchangeRequests(testId).length(), 2);
    test:assertEquals(check getCapturedHeader(testId, "chat", "authorization"), "Bearer access-1");
    // Once the cached token is past its fallback window, requests inside the backoff period return the
    // recorded error without calling the token endpoint.
    runtime:sleep(1.5);
    ai:ChatAssistantMessage|ai:Error result = provider->chat([{role: ai:USER, content: "Hi"}]);
    if result !is ai:LlmError {
        test:assertFail("Expected the recorded ai:LlmError inside the backoff period");
    }
    test:assertTrue(result.message().includes("status 503"), result.message());
    test:assertEquals(getTokenExchangeRequests(testId).length(), 2);
}
