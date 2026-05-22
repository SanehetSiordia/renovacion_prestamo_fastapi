#!/bin/bash
set -e

echo "=== [DVC] Sincronizando datos desde el almacenamiento remoto ==="
dvc pull

echo "=== [DOCKER] Iniciando servicio de FastAPI ==="
exec "$@"