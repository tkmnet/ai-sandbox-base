FROM docker.io/library/ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    bash \
    locales \
    sudo \
    neovim \
    ripgrep \
    fd-find \
    jq \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    bubblewrap \
    tmux \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

RUN sed -i 's/^# *ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen ja_JP.UTF-8

ARG USERNAME=ai
ARG UID=1000
ARG GID=1000

RUN set -eux; \
    if getent group "${GID}" >/dev/null; then \
        existing_group="$(getent group "${GID}" | cut -d: -f1)"; \
        if [ "${existing_group}" != "${USERNAME}" ] && ! getent group "${USERNAME}" >/dev/null; then \
            groupmod --new-name "${USERNAME}" "${existing_group}"; \
        fi; \
    else \
        groupadd --gid "${GID}" "${USERNAME}"; \
    fi; \
    if id -u "${USERNAME}" >/dev/null 2>&1; then \
        usermod --uid "${UID}" --gid "${GID}" "${USERNAME}"; \
    elif getent passwd "${UID}" >/dev/null; then \
        existing_user="$(getent passwd "${UID}" | cut -d: -f1)"; \
        usermod --login "${USERNAME}" --home "/home/${USERNAME}" --move-home --gid "${GID}" "${existing_user}"; \
    else \
        useradd --uid "${UID}" --gid "${GID}" -m -s /bin/bash "${USERNAME}"; \
    fi; \
    mkdir -p "/home/${USERNAME}" \
    && chown "${UID}:${GID}" "/home/${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/ai

COPY --chown=${USERNAME}:${USERNAME} init-guest.d/ /tmp/init-guest.d/
RUN for script in /tmp/init-guest.d/*.sh; do \
        bash "$script"; \
    done \
    && rm -rf /tmp/init-guest.d

ENV LANG=ja_JP.UTF-8
ENV LC_ALL=ja_JP.UTF-8
ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/bin:${PATH}"

CMD ["bash"]
