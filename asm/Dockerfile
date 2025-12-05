FROM --platform=linux/amd64 debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    nasm \
    binutils \
    make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy directory structure
COPY Makefile ./
COPY include/ ./include/
COPY lib/ ./lib/
COPY src/ ./src/

# Build using Makefile
RUN make && chmod +x gift_core

CMD ["./gift_core"]