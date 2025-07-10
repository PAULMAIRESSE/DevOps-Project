# Dockerfile for pipeline execution container
FROM docker:latest

# Install necessary tools
RUN apk add --no-cache git curl jq docker-cli docker-compose

# Create workspace
WORKDIR /workspace

# Copy the pipeline script into the image
COPY pipeline.sh .

# Make it executable
RUN chmod +x pipeline.sh

# Entry point: run the script
ENTRYPOINT ["sh", "pipeline.sh"]