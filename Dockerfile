FROM debian:bullseye-slim
LABEL maintainer="Klaas Jan Dijksterhuis"

ARG USERNAME=dev-rsa
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        whiptail \
        easy-rsa \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin/easyrsa

USER $USERNAME

WORKDIR /pki
