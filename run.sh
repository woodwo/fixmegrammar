#!/bin/bash

# Load environment variables from .env if present
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

# Check for OpenAI API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OpenAI API key not found. Please set OPENAI_API_KEY environment variable."
    exit 1
fi

# Run the app
swift run FixMeGrammar
