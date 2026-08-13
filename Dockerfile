# ── Etapa 1- Herramientas de Datos (AWS CLI + DVC) ────────────────
FROM python:3.12-slim AS dvc-tools

WORKDIR /workspace

RUN pip install --no-cache-dir awscli "dvc[s3]"

# ── Etapa 2- Servidor de MLflow ─────────────────────────────────
FROM python:3.12-slim AS mlflow-server

WORKDIR /mlruns

RUN pip install --no-cache-dir mlflow

EXPOSE 5000

CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000", "--backend-store-uri", "sqlite:////mlruns/mlflow.db", "--allowed-hosts", "*"]

# ── Etapa 3- Servidor de FASTAPI ─────────────────────────────────
FROM python:3.12-slim AS dev

ARG APP_VERSION
ARG PORT_LOCAL
ARG PORT_REMOTE
ARG STAGE

# ── Metadatos ────────────────────────────────────────────────────────────────
LABEL maintainer="MLOps Renovacion de Prestamo"
LABEL description="API de predicción para renovacion de Prestamo"
LABEL version=${APP_VERSION}

# No mostrar actualización de pip y evitar escritura de archivos .pyc
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION} \
    PORT_REMOTE=${PORT_REMOTE} \
    PORT_LOCAL=${PORT_LOCAL} \
    STAGE=${STAGE}

WORKDIR /app

COPY requirements.txt .

# ── Instalar dependencias del sistema (mínimas) ───────────────────────────────
#RUN apt-get update && apt-get install -y --no-install-recommends \
#    gcc \
#    python3-dev \
#    && pip install --no-cache-dir -r requirements.txt \
#    && apt-get purge -y --auto-remove gcc python3-dev \
#    && rm -rf /var/lib/apt/lists/* /root/.cache/pip

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefer-binary -r requirements.txt
    
#COPIAR ARCHIVOS EN DIRECTORIO LOCAL EN DIRECTORIO DE LA IMAGEN
COPY . .

#EXPOSICION DEL PUERTO DE LA IMAGEN
EXPOSE ${PORT_REMOTE}

# ── Health check para que Docker sepa si el contenedor está sano ──────────────
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python -c "import httpx, os; port = os.getenv('PORT_REMOTE'); httpx.get(f'http://localhost:{port}/health')"

#COMANDOS DE EJECUCION DEL APLICATIVO: uvicorn api.app:app --host 0.0.0.0 --port 8000 --reload
CMD ["uvicorn", "api.app:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]