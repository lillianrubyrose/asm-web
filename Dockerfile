FROM docker.io/debian:bookworm-slim

COPY main.asm /web/main.asm

RUN apt update && \
    apt install -yyq fasm && \
    cd /web/ && \
    fasm main.asm && \
    chmod +x ./main

CMD [ "/web/main" ]
