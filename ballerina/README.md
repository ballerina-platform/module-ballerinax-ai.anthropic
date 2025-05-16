## Overview

This module offers APIs for connecting with Anthropic Large Language Models (LLM).

## Prerequisites

Before using this module in your Ballerina application, first you must obtain the nessary configuration to engage the LLM.

- Create an [Anthropic account](https://www.anthropic.com/signup).
- Obtain an API key by following [these instructions](https://docs.anthropic.com/en/api/getting-started).

## Quickstart

To use the `ai.model.provider.anthropic` module in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

Import the `ai.model.provider.anthropic;` module.

```ballerina
import ballerinax/ai.model.provider.anthropic;
```

### Step 2: Intialize the Model Provider

Here's how to initialize the Model Provider:

```ballerina
import ballerina/ai;
import ballerinax/ai.model.provider.anthropic;

final ai:ModelProvider openAiModel = check new anthropic:Provider("anthropicAiApiKey", anthropic:CLAUDE_3_7_SONNET_20250219, "2023-06-01");
```

### Step 4: Invoke chat completion

```
ai:ChatMessage[] chatMessages = [{role: "user", content: "hi"}];
ai:ChatAssistantMessage response = check openAiModel->chat(chatMessages, tools = []);

chatMessages.push(response);
```
