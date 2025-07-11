FROM debian:stable-slim

ARG SUDACHI_VERSION=0.7.5
ARG DICTIONARY_VERSION=20250515

ENV SUDACHI_VERSION=${SUDACHI_VERSION}
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update -yqq \
    && apt-get install -yqq --no-install-recommends \
    ca-certificates \
    curl \
    openjdk-17-jre-headless \
    unzip \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -d /app work \
    && chown work:work /app

ADD --chown=work:work https://github.com/WorksApplications/Sudachi/releases/download/v${SUDACHI_VERSION}/sudachi-${SUDACHI_VERSION}-executable.zip /app/sudachi.zip
ADD --chown=work:work http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict/sudachi-dictionary-${DICTIONARY_VERSION}-full.zip /app/sudachi-dictionary.zip

USER work
WORKDIR /app

RUN unzip sudachi.zip -d sudachi \
    && rm sudachi.zip \
    && unzip sudachi-dictionary.zip -d sudachi/dictionary \
    && rm sudachi-dictionary.zip \
    && mv sudachi/dictionary/sudachi-dictionary-${DICTIONARY_VERSION}/*.dic sudachi/system_core.dic

RUN curl https://raw.githubusercontent.com/luvit/lit/1e57bc0bdec35ed64a8fba37899e66817a912715/get-lit.sh | sh

COPY --chown=work:work src ./src
COPY --chown=work:work deps ./deps

CMD ["./luvit", "src/boot.lua"]