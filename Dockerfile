# ── Etapa 1- Herramientas de Datos (AWS CLI + DVC) ────────────────
FROM python:3.12-slim AS dvc_aws_server

WORKDIR /workspace

RUN pip install --no-cache-dir awscli "dvc[s3]"

# ── Etapa 2- Servidor de MLflow ─────────────────────────────────
FROM python:3.12-slim AS mlflow_server

WORKDIR /mlruns

RUN pip install --no-cache-dir mlflow

EXPOSE 5000

CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000", "--backend-store-uri", "sqlite:////mlruns/mlflow.db", "--allowed-hosts", "*"]

# ── Etapa 3- Servidor de Entrenamiento de Modelo ─────────────────────────────────
FROM python:3.12-slim AS training_server

ARG APP_VERSION
ARG PORT_LOCAL
ARG PORT_REMOTE

LABEL maintainer="MLOps Renovacion de Prestamo"
LABEL description="API de predicción para renovacion de Prestamo"
LABEL version=${APP_VERSION}

# No mostrar actualización de pip y evitar escritura de archivos .pyc
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements/ /app/requirements/

# ── Instalar dependencias del sistema (mínimas) ───────────────────────────────
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefer-binary -r /app/requirements/training.txt

CMD ["tail", "-f", "/dev/null"]