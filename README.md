# FixMeGrammar - LLM-Augmented Clipboard for macOS

FixMeGrammar is a utility that monitors your clipboard for English text and automatically fixes grammar using an LLM (GPT). When you copy text, it automatically checks if it's natural language (not code), sends it to GPT for grammar correction, and puts the corrected text back into your clipboard.

## Features

- Automatically monitors clipboard for changes
- Detects if copied content is code and skips processing
- Fixes grammar and spelling in English text using GPT
- Status icon in menu bar that flickers when text is fixed
- Minimal UI with just a status icon

## Requirements

- macOS 12.0 or newer
- Swift 5.5 or newer
- OpenAI API key

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/fixmegrammar.git
   cd fixmegrammar
   ```

2. Run the setup script, which will build the project and prompt for your OpenAI API key:
   ```
   ./setup.sh
   ```

3. The setup script will create a run.sh file that you can use to run the application:
   ```
   ./run.sh
   ```

## Manual Setup

If you prefer to set up manually instead of using the setup script:

1. Set your OpenAI API key as an environment variable:
   ```
   export OPENAI_API_KEY="your-api-key-here"
   ```

2. Build the project:
   ```
   swift build
   ```

3. Run the application:
   ```
   swift run
   ```

## Usage

1. After starting the application, you'll see a clipboard icon (📎) in your menu bar.
2. Copy any English text to your clipboard.
3. The application will automatically check if it contains grammar issues.
4. If issues are found and fixed, the clipboard content will be replaced with the corrected text, and the menu bar icon will briefly flash (✓).
5. If the copied content is detected as code, it will be ignored.
6. To exit the application, click on the menu bar icon and select "Exit".

## Troubleshooting

If you encounter issues:

1. Verify your OpenAI API key is correct
2. Check the terminal output for any error messages
3. Make sure you're running macOS 12.0 or newer
4. Ensure you have Swift 5.5 or newer installed

## How It Works

- The application checks the clipboard every second for changes.
- When text is detected, it uses sophisticated heuristics to determine if it's code.
- If it's not code, it sends the text to OpenAI's GPT API with instructions to fix grammar.
- If the API returns corrected text, it replaces the clipboard content.

## Note

This is a command-line application that runs in the background. To use it regularly, you might want to create a Launch Agent to start it automatically when you log in.

## License

MIT 