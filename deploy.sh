#!/bin/bash
# deploy.sh — Flujo manual de despliegue desarrollo

set -e  # salir si cualquier comando falla

ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    echo "Cargando configuración local desde $ENV_FILE..."
    # Exporta las variables ignorando líneas vacías y comentarios
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "⚠️ Advertencia: No se encontró el archivo $ENV_FILE. Se usarán variables del sistema."
fi

VERSION=${1:-${IMAGE_VERSION:-latest}}
IMAGE_NAME=${IMAGE_NAME:-"renovacion_prestamo-image"}
COMPOSE_FILE="compose.yml"

echo "===================================================================="
echo " DEPLOY DESARROLLO — Entorno: ${ENV:-dev} | Versión: $VERSION"
echo "===================================================================="

# ── PASO 1: Guardar versión actual para rollback ──────────────────────────────
echo "[1/5] Guardando versión actual para rollback..."
CURRENT=$(docker images --format "{{.Tag}}" "$IMAGE_NAME" 2>/dev/null | head -1 || echo "none")
echo "  Versión actual: $CURRENT"

# ── PASO 2: Build de todas las imágenes ──────────────────────────────────────
echo "[2/5] Construyendo imágenes Docker..."
docker compose -f $COMPOSE_FILE build
echo "  Build OK"

# ── PASO 3: Levantar el entorno --------──────────────────────────────────────
echo "[3/5] Levantando entorno completo..."
docker compose -f $COMPOSE_FILE up --build -d
echo "  Esperando 30 segundos para que los servicios inicien..."
sleep 30

# ── PASO 4: Tag de la versión ─────────────────────────────────────────────────
echo "[4/5] Tagging imagen de la versión como latest para consistencia..."
docker tag "$IMAGE_NAME:$VERSION" "$IMAGE_NAME:latest"
echo "  Imagen taggeada exitosamente: $IMAGE_NAME:latest"

# ── PASO 5: Verificación final ────────────────────────────────────────────────
echo "[5/5] Verificación final..."
VERIFY_PORT_LOCAL=${PORT_LOCAL:-8085}
VERIFY_PORT_MLFLOW=${MLFLOW_PORT:-5000}
echo "  Enviando petición de prueba al endpoint de salud en el puerto $VERIFY_PORT_LOCAL..."

if curl -sf "http://localhost:$VERIFY_PORT_LOCAL/health" | python3 -m json.tool; then
    echo "  Healthcheck exitoso ✔"
else
    echo "❌ Error: El servicio FastAPI no respondió correctamente en el puerto $VERIFY_PORT_LOCAL"
    exit 1
fi

echo ""
echo "===================================================================="
echo " DEPLOY EXITOSO — $IMAGE_NAME:$VERSION"
echo " API   : http://localhost:$VERIFY_PORT_LOCAL"
echo " Docs  : http://localhost:$VERIFY_PORT_LOCAL/docs"
echo " MLflow: http://localhost:$VERIFY_PORT_MLFLOW"
echo "===================================================================="
