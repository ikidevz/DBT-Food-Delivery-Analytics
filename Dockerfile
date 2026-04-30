# ─────────────────────────────────────────────────────────────────────────────
# Food Delivery Analytics — dbt Docker Image
# Base    : python:3.12-slim  (upgraded from 3.11)
# dbt     : dbt-core==1.11.6 + dbt-postgres==1.10.0  (latest stable, Apr 2025)
# ─────────────────────────────────────────────────────────────────────────────

FROM python:3.12-slim

LABEL maintainer="your-name"
LABEL project="food-delivery-analytics"
LABEL dbt-version="1.11.6"

WORKDIR /usr/app

# System deps — git is needed for dbt deps (packages from GitHub)
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip first
RUN pip install --no-cache-dir --upgrade pip

# Install latest stable dbt + postgres adapter
# Note: from dbt-core 1.8+ the adapter is decoupled — install both explicitly
RUN pip install --no-cache-dir \
    dbt-core==1.11.6 \
    dbt-postgres==1.10.0

# Copy project files into the image
COPY dbt_project/ /usr/app/

# Verify install on build (good CI practice)
RUN dbt --version

ENTRYPOINT ["dbt"]
CMD ["run"]
