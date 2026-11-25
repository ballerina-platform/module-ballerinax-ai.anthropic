## Overview

The `ai.anthropic` module provides an Anthropic-backed `ModelProvider` implementation for the [`ballerina/ai`](https://central.ballerina.io/ballerina/ai/latest) agent framework. Use it to drive Anthropic Claude models (Claude 3.5 Sonnet, Claude 3 Opus, and others) from Ballerina AI agents and other `ai`-module abstractions, rather than calling the Anthropic REST API directly.

### Key Features

- Connect and interact with Anthropic Large Language Models (LLMs)
- Support for Claude 3.5 Sonnet, Claude 3 Opus, and other Claude models
- Efficient handling of conversational prompts and responses
- Secure communication with API key authentication

## Prerequisites

Before using this module in your Ballerina application, first you must obtain the nessary configuration to engage the LLM.

- Create an [Anthropic account](https://www.anthropic.com/signup).
- Obtain an API key by following [these instructions](https://docs.anthropic.com/en/api/getting-started).

## Quickstart

To use the `ai.anthropic` module in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

Import the `ai.anthropic;` module.

```ballerina
import ballerinax/ai.anthropic;
```

### Step 2: Intialize the Model Provider

Here's how to initialize the Model Provider:

```ballerina
import ballerina/ai;
import ballerinax/ai.anthropic;

final ai:ModelProvider anthropicModel = check new anthropic:ModelProvider("anthropicAiApiKey", anthropic:CLAUDE_SONNET_4_6);
```

The first argument, `apiKey`, sets how the connector authenticates with the Anthropic API. It keeps its name so that existing code still compiles, but it accepts any of the following:

- **API key** (`string`): sent in the `x-api-key` header, as in the example above.

- **API key with a workspace** (`anthropic:ApiKeyConfig`): sent in the `Authorization: Bearer` header. Set `workspaceId` when the key is a personal or service account key that is not scoped to a workspace.

    ```ballerina
    final ai:ModelProvider anthropicModel = check new anthropic:ModelProvider(
        {apiKey: "anthropicAiApiKey", workspaceId: "wrkspc_..."}, anthropic:CLAUDE_SONNET_4_6);
    ```

- **Workload Identity Federation** (`anthropic:WorkloadIdentityConfig`): exchanges an identity token from your identity provider (for example, AWS, Google Cloud, Microsoft Entra ID, Kubernetes, or GitHub Actions) for a short-lived Anthropic access token, so no API key is needed. The connector reuses the access token until it expires. An identity token can usually be exchanged only once, so after that, create a new model provider with a new identity token. See [Workload Identity Federation](https://platform.claude.com/docs/en/manage-claude/workload-identity-federation) for how to set up the federation rule and service account.

    ```ballerina
    final ai:ModelProvider anthropicModel = check new anthropic:ModelProvider({
        federationRuleId: "fdrl_...",
        organizationId: "00000000-0000-0000-0000-000000000000",
        identityToken: "<identity token (JWT) from your identity provider>"
    }, anthropic:CLAUDE_SONNET_4_6);
    ```

- **Access token** (`http:BearerTokenConfig`): an access token obtained elsewhere, sent in the `Authorization: Bearer` header. The connector does not refresh it, so requests fail once it expires.

    ```ballerina
    final ai:ModelProvider anthropicModel = check new anthropic:ModelProvider({token: "sk-ant-oat01-..."}, anthropic:CLAUDE_SONNET_4_6);
    ```

### Step 4: Invoke chat completion

```ballerina
ai:ChatMessage[] chatMessages = [{role: "user", content: "hi"}];
ai:ChatAssistantMessage response = check anthropicModel->chat(chatMessages, tools = []);

chatMessages.push(response);
```
