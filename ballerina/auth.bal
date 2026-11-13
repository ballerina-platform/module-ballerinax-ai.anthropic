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
import ballerina/io;
import ballerina/time;

const DEFAULT_TOKEN_URL = "https://api.anthropic.com/v1/oauth/token";
const JWT_BEARER_GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer";
const API_KEY_HEADER = "x-api-key";
const AUTHORIZATION_HEADER = "authorization";
const WORKSPACE_ID_HEADER = "anthropic-workspace-id";

// A cached access token is refreshed this many seconds before it expires.
const decimal TOKEN_REFRESH_BUFFER_SECONDS = 120;
// If a refresh fails, the cached access token is still used until this many seconds before it expires.
const decimal TOKEN_EXPIRY_BUFFER_SECONDS = 30;

# Authentication with an Anthropic API key.
# See https://platform.claude.com/docs/en/manage-claude/authentication
public type ApiKeyConfig record {|
    # The Anthropic API key, sent in the `x-api-key` header
    @display {label: "API Key"}
    string apiKey;
    # The workspace to run requests in (`wrkspc_...`), sent in the `anthropic-workspace-id` header.
    # Required for a personal or service account key that is not scoped to a workspace
    @display {label: "Workspace ID"}
    string workspaceId?;
|};

# Authentication with Workload Identity Federation. The connector exchanges an identity token issued by your
# identity provider (for example, AWS, Google Cloud, Microsoft Entra ID, Kubernetes, or GitHub Actions) for a
# short-lived Anthropic access token, and refreshes the access token before it expires.
# See https://platform.claude.com/docs/en/manage-claude/workload-identity-federation
public type WorkloadIdentityConfig record {|
    # The ID of the federation rule to evaluate (`fdrl_...`)
    @display {label: "Federation Rule ID"}
    string federationRuleId;
    # The ID of the Anthropic organization (UUID)
    @display {label: "Organization ID"}
    string organizationId;
    # The ID of the service account that the access token acts as (`svac_...`)
    @display {label: "Service Account ID"}
    string serviceAccountId;
    # The workspace to scope the access token to (`wrkspc_...`). Required when the federation rule is enabled
    # for more than one workspace
    @display {label: "Workspace ID"}
    string workspaceId?;
    # Where to get the identity token (JWT) issued by your identity provider. The connector gets the identity
    # token again for every exchange
    @display {label: "Identity Token"}
    IdentityTokenSource identityToken;
    # The URL of the Anthropic token exchange endpoint
    @display {label: "Token URL"}
    string tokenUrl = DEFAULT_TOKEN_URL;
|};

# The source of the identity token (JWT) exchanged for an Anthropic access token.
# A `string` is the identity token itself. An identity token with a `jti` claim can be exchanged only once, so a
# fixed `string` stops working when the first access token expires. Prefer `IdentityTokenFile` or
# `IdentityTokenProvider`, which provide a fresh identity token for every exchange.
public type IdentityTokenSource IdentityTokenFile|IdentityTokenProvider|string;

# A file containing the identity token. The file is read again for every exchange, so identity tokens that
# rotate on disk (for example, Kubernetes projected service account tokens) are always current.
public type IdentityTokenFile record {|
    # The path to the file containing the identity token
    string path;
|};

# A function that returns a fresh identity token. It is called for every exchange. Use it for identity tokens
# fetched over HTTP, such as from the Google Cloud metadata server, Azure IMDS, or GitHub Actions.
public type IdentityTokenProvider isolated function () returns string|error;

# Authentication configurations for the Anthropic model provider.
# - `ApiKeyConfig`: An Anthropic API key
# - `WorkloadIdentityConfig`: Workload Identity Federation, with short-lived access tokens refreshed automatically
# - `http:BearerTokenConfig`: An access token obtained elsewhere, sent in the `Authorization: Bearer` header.
# The connector does not refresh it, so requests fail once it expires
public type AuthConfig ApiKeyConfig|WorkloadIdentityConfig|http:BearerTokenConfig;

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
    string service_account_id;
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
    private final IdentityTokenSource & readonly identityToken;
    private string? accessToken = ();
    // The monotonic time, in seconds, at which the cached access token expires.
    private decimal expiresAt = 0;

    isolated function init(http:Client tokenClient, TokenExchangeParams & readonly exchangeParams,
            IdentityTokenSource & readonly identityToken) {
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
            if cachedToken is string && now < self.expiresAt - TOKEN_REFRESH_BUFFER_SECONDS {
                return cachedToken;
            }
            TokenExchangeResponse|ai:Error response =
                exchangeIdentityToken(self.tokenClient, self.exchangeParams, self.identityToken);
            if response is ai:Error {
                // Keep using the cached access token while it is still valid.
                if cachedToken is string && now < self.expiresAt - TOKEN_EXPIRY_BUFFER_SECONDS {
                    return cachedToken;
                }
                return response;
            }
            self.accessToken = response.access_token;
            self.expiresAt = now + <decimal>response.expires_in;
            return response.access_token;
        }
    }
}

# Creates the authentication provider for the given authentication configuration.
#
# + auth - The authentication configuration
# + clientConfig - The HTTP client configuration, used for the token exchange endpoint
# + return - The authentication provider, or an `ai:Error` if it could not be created
isolated function createAuthProvider(AuthConfig auth, http:ClientConfiguration clientConfig)
        returns AuthProvider|ai:Error {
    if auth is ApiKeyConfig {
        map<string> headers = {[API_KEY_HEADER]: auth.apiKey};
        string? workspaceId = auth.workspaceId;
        if workspaceId is string {
            headers[WORKSPACE_ID_HEADER] = workspaceId;
        }
        return new StaticAuthProvider(headers.cloneReadOnly());
    }
    if auth is http:BearerTokenConfig {
        return new StaticAuthProvider({[AUTHORIZATION_HEADER]: string `Bearer ${auth.token}`});
    }

    http:Client|error tokenClient = new (auth.tokenUrl, clientConfig);
    if tokenClient is error {
        return error ai:Error("Failed to initialize the Workload Identity Federation token client", tokenClient);
    }
    TokenExchangeParams exchangeParams = {
        federation_rule_id: auth.federationRuleId,
        organization_id: auth.organizationId,
        service_account_id: auth.serviceAccountId
    };
    string? workspaceId = auth.workspaceId;
    if workspaceId is string {
        exchangeParams.workspace_id = workspaceId;
    }
    IdentityTokenSource identityToken = auth.identityToken;
    IdentityTokenSource & readonly readonlyIdentityToken = identityToken is IdentityTokenFile
        ? identityToken.cloneReadOnly() : identityToken;
    return new WorkloadIdentityAuthProvider(tokenClient, exchangeParams.cloneReadOnly(), readonlyIdentityToken);
}

# Exchanges the identity token for a short-lived Anthropic access token.
#
# + tokenClient - The HTTP client for the token exchange endpoint
# + exchangeParams - The fields of the token exchange request that do not change between exchanges
# + identityToken - The source of the identity token
# + return - The token exchange response, or an `ai:Error` if the exchange fails
isolated function exchangeIdentityToken(http:Client tokenClient, TokenExchangeParams & readonly exchangeParams,
        IdentityTokenSource & readonly identityToken) returns TokenExchangeResponse|ai:Error {
    string|error assertion = getIdentityToken(identityToken);
    if assertion is error {
        return error ai:Error("Failed to get the identity token for Workload Identity Federation", assertion);
    }
    map<json> request = {
        grant_type: JWT_BEARER_GRANT_TYPE,
        assertion: assertion.trim(),
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

isolated function getIdentityToken(IdentityTokenSource & readonly identityToken) returns string|error {
    if identityToken is string {
        return identityToken;
    }
    if identityToken is IdentityTokenFile {
        return io:fileReadString(identityToken.path);
    }
    return identityToken();
}
