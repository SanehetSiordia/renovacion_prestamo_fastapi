# ETAPA 1: Builder (Compilación aislada y limpia)
FROM python:3.12-slim as builder

WORKDIR /app

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-prod.txt .

RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements-prod.txt

# ETAPA 2: Production
FROM python:3.12-slim as prod

ARG APP_VERSION
ARG PORT_REMOTE
ARG PORT_LOCAL

LABEL maintainer="MLOps Renovacion de Prestamo"
LABEL description="API de predicción para renovacion de Prestamo"
LABEL version=${APP_VERSION}

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION} \
    PORT_REMOTE=${PORT_REMOTE} \
    PORT_LOCAL=${PORT_LOCAL}

WORKDIR /app

COPY --from=builder /app/wheels /images/wheels

RUN pip install --no-cache-dir /images/wheels/* && rm -rf /images/wheels

COPY api/ ./api/
COPY artifacts/ ./artifacts/
COPY config.py .

EXPOSE ${PORT_REMOTE}

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python -c "import httpx, os; port = os.getenv('PORT_REMOTE', '8000'); httpx.get(f'http://localhost:{port}/health')"

CMD ["uvicorn", "api.app:app", "--host", "0.0.0.0", "--port", "8000"]