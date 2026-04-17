FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Switch to Azure's Ubuntu mirror and add apt retries. archive.ubuntu.com has
# periodic outages that brick feature installs; azure.archive.ubuntu.com is
# hosted in the same infrastructure as GitHub Actions runners and is far more
# reliable. Retries also absorb short blips on any mirror.
RUN set -e; \
    printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' \
      > /etc/apt/apt.conf.d/80-retries; \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
        sed -i \
          -e 's|http://archive.ubuntu.com/ubuntu/\?|http://azure.archive.ubuntu.com/ubuntu/|g' \
          -e 's|http://security.ubuntu.com/ubuntu/\?|http://azure.archive.ubuntu.com/ubuntu/|g' \
          /etc/apt/sources.list.d/ubuntu.sources; \
    fi; \
    if [ -f /etc/apt/sources.list ]; then \
        sed -i \
          -e 's|http://archive.ubuntu.com/ubuntu/\?|http://azure.archive.ubuntu.com/ubuntu/|g' \
          -e 's|http://security.ubuntu.com/ubuntu/\?|http://azure.archive.ubuntu.com/ubuntu/|g' \
          /etc/apt/sources.list; \
    fi
