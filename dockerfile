FROM ubuntu:latest

# Set the working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \ 
    python3 \
    python3-pip \
    groff-base \
    jq \
    curl \
    git \ 

# Install trufflehog
RUN pip3 install trufflehog

# Install AWSCLI
RUN pip3 install awscli

# Copy the scan script
COPY ./truffle_scan.sh /app/truffle_scan.sh
RUN chmod +x /app/truffle_scan.sh

# Set env variable
ENV GITHUB_REPO_URL=<github_repo_here>

# Run the entry script
ENTRYPOINT ["/app/truffle_scan.sh"]
