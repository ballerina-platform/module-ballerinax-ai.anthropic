// Copyright (c) 2026 WSO2 LLC (http://www.wso2.com).
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
import ballerina/http;
import ballerina/time;

const TOKEN_PATH = "/oauth/token";
const JWT_BEARER_GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer";
const AUTHORIZATION_HEADER = "authorization";
const API_KEY_HEADER = "x-api-key";
const WORKSPACE_ID_HEADER = "anthropic-workspace-id";

// A cached access token is refreshed this many seconds before it expires, or halfway through its lifetime if
// that is sooner, so a short-lived access token is not exchanged again on every request.
const decimal TOKEN_REFRESH_BUFFER_SECONDS = 120;
// If a refresh fails, the cached access token is still used until this many seconds before it expires, or until
// three quarters of its lifetime if that is sooner.
const decimal TOKEN_EXPIRY_BUFFER_SECONDS = 30;

# Authentication with an Anthropic API key.
# See https://platform.claude.com/docs/en/manage-claude/authentication
public type ApiKeyConfig record {|
    # The Anthropic API key, sent in the `Authorization: Bearer` header
    @display {label: "API Key"}
    string apiKey;
    # The workspace to run requests in (`wrkspc_...`), sent in the `anthropic-workspace-id` header.
    # Required for a personal or service account key that is not scoped to a workspace
    @display {label: "Workspace ID"}
    string workspaceId?;
|};

# Authentication with Workload Identity Federation. The connector exchanges an identity token issued by your
# identity provider (for example, AWS, Google Cloud, Microsoft Entra ID, Kubernetes, or GitHub Actions) for a
# short-lived Anthropic access token, and reuses the access token until it is about to expire.
# See https://platform.claude.com/docs/en/manage-claude/workload-identity-federation
public type WorkloadIdentityConfig record {|
    # The ID of the federation rule to evaluate (`fdrl_...`)
    @display {label: "Federation Rule ID"}
    string federationRuleId;
    # The ID of the Anthropic organization (UUID)
    @display {label: "Organization ID"}
    string organizationId;
    # The ID of the service account that the access token acts as (`svac_...`). Optional, as the federation rule
    # determines the service account. If set, it must be the rule's service account
    @display {label: "Service Account ID"}
    string serviceAccountId?;
    # The workspace to scope the access token to (`wrkspc_...`). Required when the federation rule is enabled
    # for more than one workspace
    @display {label: "Workspace ID"}
    string workspaceId?;
    # The identity token (JWT) issued by your identity provider. The same identity token is used for every
    # exchange. Anthropic accepts an identity token with a `jti` claim only once, and none after it expires, so
    # once the access token expires, create a new model provider with a new identity token
    @display {label: "Identity Token"}
    string identityToken;
    # The URL of the Anthropic token exchange endpoint. Defaults to `/oauth/token` under the service URL of the
    # model provider
    @display {label: "Token URL"}
    string tokenUrl?;
|};

# Provides the authentication headers for each request to the Anthropic API.
type AuthProvider isolated object {
    # Returns the authentication headers to send with a request.
    #
    # + return - The authentication headers, or an `ai:Error` if they could not be obtained
    isolated function getHeaders() returns map<string> & readonly|ai:Error;
};

# Provides headers that do not change, for API key and bearer token authentication.
isolated class StaticAuthProvider {
    *AuthProvider;
    private final map<string> & readonly headers;

    isolated function init(map<string> & readonly headers) {
        self.headers = headers;
    }

    isolated function getHeaders() returns map<string> & readonly|ai:Error => self.headers;
}

# Adds the authentication headers to the request headers.
#
# + headers - The request headers
# + authHeaders - The authentication headers
isolated function addAuthHeaders(map<string> headers, map<string> & readonly authHeaders) {
    foreach [string, string] [name, value] in authHeaders.entries() {
        headers[name] = value;
    }
}

# The fields of the token exchange request that do not change between exchanges.
type TokenExchangeParams record {|
    # The ID of the federation rule to evaluate
    string federation_rule_id;
    # The ID of the Anthropic organization
    string organization_id;
    # The ID of the service account that the access token acts as
    string service_account_id?;
    # The workspace to scope the access token to
    string workspace_id?;
|};

# The response of the token exchange endpoint.
type TokenExchangeResponse record {
    # The short-lived Anthropic access token
    string access_token;
    # The number of seconds until the access token expires
    int expires_in;
};

# Provides the headers for Workload Identity Federation. Exchanges the identity token for an access token,
# caches the access token, and exchanges again before it expires.
isolated class WorkloadIdentityAuthProvider {
    *AuthProvider;
    private final http:Client tokenClient;
    private final TokenExchangeParams & readonly exchangeParams;
    private final string identityToken;
    private string? accessToken = ();
    // The monotonic time, in seconds, after which the cached access token is refreshed.
    private decimal refreshAt = 0;
    // The monotonic time, in seconds, until which the cached access token is used if a refresh fails.
    private decimal usableUntil = 0;

    isolated function init(http:Client tokenClient, TokenExchangeParams & readonly exchangeParams,
            string identityToken) {
        self.tokenClient = tokenClient;
        self.exchangeParams = exchangeParams;
        self.identityToken = identityToken;
    }

    isolated function getHeaders() returns map<string> & readonly|ai:Error {
        string accessToken = check self.getAccessToken();
        return {[AUTHORIZATION_HEADER]: string `Bearer ${accessToken}`};
    }

    # Returns the cached access token, exchanging the identity token for a new one when the cached access token
    # is about to expire. The exchange runs inside the lock so that concurrent requests trigger only one exchange,
    # as an identity token with a `jti` claim can be exchanged only once.
    #
    # + return - The access token, or an `ai:Error` if the exchange fails
    isolated function getAccessToken() returns string|ai:Error {
        lock {
            decimal now = time:monotonicNow();
            string? cachedToken = self.accessToken;
            if cachedToken is string && now < self.refreshAt {
                return cachedToken;
            }
            TokenExchangeResponse|ai:Error response =
                exchangeIdentityToken(self.tokenClient, self.exchangeParams, self.identityToken);
            if response is ai:Error {
                // Keep using the cached access token while it is still valid. The exchange may have taken a
                // while to fail, so check against the current time.
                if cachedToken is string && time:monotonicNow() < self.usableUntil {
                    return cachedToken;
                }
                return response;
            }
            decimal expiresIn = <decimal>response.expires_in;
            self.accessToken = response.access_token;
            self.refreshAt = now + expiresIn - decimal:min(TOKEN_REFRESH_BUFFER_SECONDS, expiresIn / 2);
            self.usableUntil = now + expiresIn - decimal:min(TOKEN_EXPIRY_BUFFER_SECONDS, expiresIn / 4);
            return response.access_token;
        }
    }
}

# Creates the authentication provider for the given authentication configuration.
#
# + auth - The authentication configuration. A `string` is an Anthropic API key
# + serviceUrl - The base URL of the Anthropic API. The default token exchange endpoint is `/oauth/token` under it
# + clientConfig - The HTTP client configuration, used for the token exchange endpoint without its retry
# configuration
# + return - The authentication provider, or an `ai:Error` if it could not be created
isolated function createAuthProvider(string|ApiKeyConfig|WorkloadIdentityConfig|http:BearerTokenConfig auth,
        string serviceUrl, http:ClientConfiguration clientConfig) returns AuthProvider|ai:Error {
    if auth is string {
        // Sent in the `x-api-key` header, as in 1.x, so existing users see no change on the wire.
        return new StaticAuthProvider({[API_KEY_HEADER]: check validateApiKey(auth)});
    }
    if auth is ApiKeyConfig {
        map<string> headers = {[AUTHORIZATION_HEADER]: string `Bearer ${check validateApiKey(auth.apiKey)}`};
        string? workspaceId = auth.workspaceId;
        if workspaceId is string {
            headers[WORKSPACE_ID_HEADER] = workspaceId;
        }
        return new StaticAuthProvider(headers.cloneReadOnly());
    }
    if auth is http:BearerTokenConfig {
        return new StaticAuthProvider({[AUTHORIZATION_HEADER]: string `Bearer ${auth.token}`});
    }

    // The token exchange is not retried. A retry sends the same identity token again, and Anthropic rejects an
    // identity token with a `jti` claim that has already been exchanged.
    var {retryConfig: _, ...tokenClientConfig} = clientConfig;
    string tokenUrl = auth.tokenUrl ?: string `${trimTrailingSlashes(serviceUrl)}${TOKEN_PATH}`;
    http:Client|error tokenClient = new (tokenUrl, {...tokenClientConfig});
    if tokenClient is error {
        return error ai:Error("Failed to initialize the Workload Identity Federation token client", tokenClient);
    }
    TokenExchangeParams exchangeParams = {
        federation_rule_id: auth.federationRuleId,
        organization_id: auth.organizationId
    };
    string? serviceAccountId = auth.serviceAccountId;
    if serviceAccountId is string {
        exchangeParams.service_account_id = serviceAccountId;
    }
    string? workspaceId = auth.workspaceId;
    if workspaceId is string {
        exchangeParams.workspace_id = workspaceId;
    }
    return new WorkloadIdentityAuthProvider(tokenClient, exchangeParams.cloneReadOnly(), auth.identityToken);
}

# Exchanges the identity token for a short-lived Anthropic access token.
#
# + tokenClient - The HTTP client for the token exchange endpoint
# + exchangeParams - The fields of the token exchange request that do not change between exchanges
# + identityToken - The identity token
# + return - The token exchange response, or an `ai:Error` if the exchange fails
isolated function exchangeIdentityToken(http:Client tokenClient, TokenExchangeParams & readonly exchangeParams,
        string identityToken) returns TokenExchangeResponse|ai:Error {
    map<json> request = {
        grant_type: JWT_BEARER_GRANT_TYPE,
        assertion: identityToken.trim(),
        ...exchangeParams
    };
    TokenExchangeResponse|error response = tokenClient->post("", request);
    if response is error {
        if response is http:ApplicationResponseError {
            http:Detail detail = response.detail();
            return error ai:LlmError(string `Workload Identity Federation token exchange failed with status ${
                detail.statusCode}: ${detail.body.toString()}`, response);
        }
        if response is http:ClientConnectorError|http:ResiliencyError|http:SslError {
            return error ai:LlmConnectionError("Error while connecting to the Anthropic token exchange endpoint",
                response);
        }
        return error ai:LlmError("Unexpected response from the Anthropic token exchange endpoint", response);
    }
    return response;
}

# Trims an API key, so a key read from a file or an environment variable with a trailing newline still works.
#
# + apiKey - The API key
# + return - The trimmed API key, or an `ai:Error` if it is empty
isolated function validateApiKey(string apiKey) returns string|ai:Error {
    string trimmed = apiKey.trim();
    if trimmed == "" {
        return error ai:Error("The Anthropic API key is empty");
    }
    return trimmed;
}

isolated function trimTrailingSlashes(string url) returns string {
    string result = url;
    while result.endsWith("/") {
        result = result.substring(0, result.length() - 1);
    }
    return result;
}
