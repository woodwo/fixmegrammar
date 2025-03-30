#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up FixMeGrammar...${NC}"

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo -e "${RED}Swift is not installed. Please install Swift before continuing.${NC}"
    exit 1
fi

# Check for OpenAI API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo -e "${YELLOW}OpenAI API key not found in environment variables.${NC}"
    echo -e "Please enter your OpenAI API key (it will be stored in .env file):"
    read api_key
    
    if [ -z "$api_key" ]; then
        echo -e "${RED}No API key provided. Exiting setup.${NC}"
        exit 1
    fi
    
    # Save to .env file
    echo "OPENAI_API_KEY=$api_key" > .env
    echo -e "${GREEN}API key saved to .env file.${NC}"
fi

# Build the project
echo -e "${GREEN}Building FixMeGrammar...${NC}"
swift build

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed. Please check the errors above.${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"

# Create a run script
echo -e "${GREEN}Creating run script...${NC}"
cat > run.sh << 'EOF'
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
EOF

chmod +x run.sh

echo -e "${GREEN}Setup complete!${NC}"
echo -e "Run the application with: ./run.sh" 