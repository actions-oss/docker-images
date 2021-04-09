ARG DISTRIB_ID=ubuntu
ARG DISTRIB_RELEASE=20.04
FROM ${DISTRIB_ID}:${DISTRIB_RELEASE}

ARG DISTRIB_ID=ubuntu
ARG DISTRIB_RELEASE=20.04
ARG RUNNER_USER=runner
ARG DEBIAN_FRONTEND=noninteractive

SHELL [ "/bin/bash", "-c" ]

RUN set -Eeuxo pipefail \
    && printf "Build started\n" \
    && ImageOS=${DISTRIB_ID}$(echo ${DISTRIB_RELEASE} | cut -d'.' -f 1) \
    && echo "IMAGE_OS=$ImageOS" | tee -a /etc/environment \
    && echo "ImageOS=$ImageOS" | tee -a /etc/environment \
    && echo "LSB_RELEASE=${DISTRIB_RELEASE}" | tee -a /etc/environment \
    && AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache \
    && echo "AGENT_TOOLSDIRECTORY=$AGENT_TOOLSDIRECTORY" | tee -a /etc/environment \
    && echo "RUN_TOOL_CACHE=$AGENT_TOOLSDIRECTORY" | tee -a /etc/environment \
    && echo "DEPLOYMENT_BASEPATH=/opt/runner" | tee -a /etc/environment \
    && echo "RUNNER_USER=${RUNNER_USER}" | tee -a /etc/environment \
    && echo "RUNNER_TEMP=/home/${RUNNER_USER}/work/_temp" | tee -a /etc/environment \
    && apt -yq update \
    && printf "Updated apt lists and upgraded packages\n\n" \
    && apt -yq install --no-install-recommends ssh lsb-release jq curl git wget sudo gnupg-agent ca-certificates software-properties-common apt-transport-https \
    && printf "Installed base utils\n" \
    && printf "Creating non-root user\n" \
    && groupadd -g 1000 ${RUNNER_USER} \
    && useradd -u 1000 -g ${RUNNER_USER} -G sudo -m -s /bin/bash ${RUNNER_USER} \
    && sed -i /etc/sudoers -re 's/^%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g' \
    && sed -i /etc/sudoers -re 's/^root.*/root ALL=(ALL:ALL) NOPASSWD: ALL/g' \
    && sed -i /etc/sudoers -re 's/^#includedir.*/## **Removed the include directive** ##"/g' \
    && echo "${RUNNER_USER} ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers \
    && printf "runner user: $(su - ${RUNNER_USER} -c id)\n" \
    && printf "Created non-root user $(grep ${RUNNER_USER} /etc/passwd)\n" \
    && printf "Cleaning image\n" \
    && apt-get clean \
    && rm -rf /var/cache/* \
    && rm -rf /var/log/* \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && printf "Cleaned up image\n"

ARG BUILD_TAG_VERSION=master
ARG BUILD_TAG=runner-${DISTRIB_RELEASE}
LABEL org.opencontainers.image.vendor="catthehacker"
LABEL org.opencontainers.image.authors="me@hackerc.at"
LABEL org.opencontainers.image.url="https://github.com/catthehacker/virtual-environments"
LABEL org.opencontainers.image.source="https://github.com/catthehacker/virtual-environments"
LABEL org.opencontainers.image.version=${BUILD_TAG_VERSION}
LABEL org.opencontainers.image.title=${BUILD_TAG}
LABEL org.opencontainers.image.revision=${BUILD_REF}

USER ${RUNNER_USER}:${RUNNER_USER}

WORKDIR /home/runner
