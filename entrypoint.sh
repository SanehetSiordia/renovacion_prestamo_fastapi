#!/bin/bash
set -e

echo "=== [ENTRYPOINT] Inicializando Contenedor MLOps ==="

# 1. Verificar si existen las credenciales para sincronización con DVC / S3
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "=== [ENTRYPOINT] Credenciales de AWS detectadas. Sincronizando datos con DVC... ==="
    dvc pull || echo "⚠️ Advertencia: No se pudieron descargar artefactos con DVC Pull, usando archivos locales."
else
    echo "⚠️ [ENTRYPOINT] No se encontraron credenciales de AWS. Se utilizarán los datos locales en ./data."
fi

# 2. Ejecutar el comando principal recibido en la orden CMD de Docker (ej. uvicorn)
echo "=== [ENTRYPOINT] Iniciando servicio de FastAPI ==="
exec "$@"