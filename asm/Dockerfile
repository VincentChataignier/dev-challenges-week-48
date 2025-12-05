FROM --platform=linux/amd64 debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    nasm \
    binutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY gift_core.asm .

RUN nasm -felf64 gift_core.asm -o gift_core.o && \
    ld -o gift_core gift_core.o && \
    chmod +x gift_core

CMD ["./gift_core"]