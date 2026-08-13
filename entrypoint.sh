#!/bin/bash
set -e

echo "=== [ENTRYPOINT] Inicializando Contenedor MLOps ==="

# 1. Verificar si existen las credenciales para sincronización con DVC / S3
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "=== [ENTRYPOINT] Credenciales de AWS detectadas correctamente. ==="
else
    echo "⚠️ [ENTRYPOINT] No se encontraron credenciales de AWS. Asegúrate de configurar .env."
fi

# 2. Si se pasan comandos al script los ejecuta; de lo contrario continúa de forma pasiva
if [ $# -gt 0 ]; then
    echo "=== [ENTRYPOINT] Ejecutando comando principal ==="
    exec "$@"
fi