FROM ubuntu:focal
LABEL maintainer="Chris Wieringa <cwieri39@calvin.edu>"

# Set versions and platforms
ARG S6_OVERLAY_VERSION=3.1.3.0
ARG BUILDDATE=20230210-3
ARG TZ=America/Detroit

# Do all run commands with bash
SHELL ["/bin/bash", "-c"] 

# Start with base Ubuntu
# Set timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo "$TZ" > /etc/timezone

# add a few system packages for SSSD/authentication
RUN apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    sssd \
    sssd-ad \
    sssd-krb5 \
    sssd-tools \
    libnfsidmap2 \
    libsss-idmap0 \
    libsss-nss-idmap0 \
    libnss-myhostname \
    libnss-mymachines \
    libnss-ldap \
    locales \
    krb5-user \
    sssd-krb5 && \
    rm -rf /var/lib/apt/lists/*

# add CalvinAD trusted root certificate
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/CalvinCollege-ad-CA.crt /etc/ssl/certs
RUN chmod 0644 /etc/ssl/certs/CalvinCollege-ad-CA.crt
RUN ln -s -f /etc/ssl/certs/CalvinCollege-ad-CA.crt /etc/ssl/certs/ddbc78f4.0

# krb5.conf, sssd.conf, idmapd.conf
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/krb5.conf /etc
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/nsswitch.conf /etc
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/sssd.conf /etc/sssd
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/idmapd.conf /etc
RUN chmod 0600 /etc/sssd/sssd.conf && \
    chmod 0644 /etc/krb5.conf && \
    chmod 0644 /etc/nsswitch.conf && \
    chmod 0644 /etc/idmapd.conf
RUN chown root:root /etc/sssd/sssd.conf

# pam configs
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/common-auth /etc/pam.d
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/common-session /etc/pam.d
RUN chmod 0644 /etc/pam.d/common-auth && \
    chmod 0644 /etc/pam.d/common-session

# use the secrets to edit sssd.conf appropriately
RUN --mount=type=secret,id=LDAP_BIND_USER \
    source /run/secrets/LDAP_BIND_USER && \
    sed -i 's@%%LDAP_BIND_USER%%@'"$LDAP_BIND_USER"'@g' /etc/sssd/sssd.conf
RUN --mount=type=secret,id=LDAP_BIND_PASSWORD \
    source /run/secrets/LDAP_BIND_PASSWORD && \
    sed -i 's@%%LDAP_BIND_PASSWORD%%@'"$LDAP_BIND_PASSWORD"'@g' /etc/sssd/sssd.conf
RUN --mount=type=secret,id=DEFAULT_DOMAIN_SID \
    source /run/secrets/DEFAULT_DOMAIN_SID && \
    sed -i 's@%%DEFAULT_DOMAIN_SID%%@'"$DEFAULT_DOMAIN_SID"'@g' /etc/sssd/sssd.conf

# Setup multiple stuff going on in the container instead of just single access  -------------------------#
# S6 overlay from https://github.com/just-containers/s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz && \
    rm -f /tmp/s6-overlay-*.tar.xz

ENV S6_CMD_WAIT_FOR_SERVICES=1 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

ENTRYPOINT ["/init"]
COPY s6-overlay/ /etc/s6-overlay

# Install and configure rsyslog
RUN apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y rsyslog && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/rsyslog.conf

ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/rsyslog/rsyslog.conf /etc/
RUN chmod 0644 /etc/rsyslog.conf

# Locale configuration --------------------------------------------------------#
RUN apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y locales && \
    rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV TERM xterm-256color
ENV TZ=US/Michigan

# Force set the TZ variable
COPY --chmod=0755 inc/timezone.sh /etc/profile.d/timezone.sh

# Cleanup misc files
RUN rm -f /var/log/*.log && \
    rm -f /var/log/faillog
