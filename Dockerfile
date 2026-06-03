FROM python:3.12-slim as dev

ARG APP_VERSION
ARG PORT_LOCAL
ARG PORT_REMOTE

# ── Metadatos ────────────────────────────────────────────────────────────────
LABEL maintainer="MLOps Renovacion de Prestamo"
LABEL description="API de predicción para renovacion de Prestamo"
LABEL version=${APP_VERSION}

# No mostrar actualización de pip y evitar escritura de archivos .pyc
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_ROOT_USER_ACTION=ignore
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV APP_VERSION=${APP_VERSION}
ENV PORT_REMOTE=${PORT_REMOTE}
ENV PORT_LOCAL=${PORT_LOCAL}

WORKDIR /app

COPY requirements.txt .

# ── Instalar dependencias del sistema (mínimas) ───────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && pip install --no-cache-dir -r requirements.txt \
    && apt-get purge -y --auto-remove gcc python3-dev \
    && rm -rf /var/lib/apt/lists/* /root/.cache/pip

#COPIAR ARCHIVOS EN DIRECTORIO LOCAL EN DIRECTORIO DE LA IMAGEN
COPY . .

#EXPOSICION DEL PUERTO DE LA IMAGEN
EXPOSE 8000

# ── Health check para que Docker sepa si el contenedor está sano ──────────────
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python -c "import httpx, os; port = os.getenv('PORT_REMOTE'); httpx.get(f'http://localhost:{port}/health')"

#ENTRYPOINT PARA PREPARAR DATOS DEL CMD
#ENTRYPOINT ["./entrypoint.sh"]

#COMANDOS DE EJECUCION DEL APLICATIVO: uvicorn api.app:app --host 0.0.0.0 --port 8000 --reload
CMD ["uvicorn", "api.app:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]