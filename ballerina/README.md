## Overview

Anthropic provides high-performance, safe, and reliable large language models (LLMs).

The Anthropic connector offers APIs for connecting with Anthropic LLMs, enabling the integration of advanced conversational AI and language processing capabilities into applications.

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

final ai:ModelProvider anthropicModel = check new anthropic:ModelProvider("anthropicAiApiKey", anthropic:CLAUDE_3_7_SONNET_20250219, "2023-06-01");
```

### Step 4: Invoke chat completion

```ballerina
ai:ChatMessage[] chatMessages = [{role: "user", content: "hi"}];
ai:ChatAssistantMessage response = check anthropicModel->chat(chatMessages, tools = []);

chatMessages.push(response);
```
