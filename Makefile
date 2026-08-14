# Makefile — Pipeline CI/CD Local + Desarrollo (Renovación de Préstamo)

-include .env
export

.PHONY: create-dirs download-dvc dvc-push \
        all train test validate versions check-training build-training build-serving \
        dev-up dev-down dev-logs dev-logs-api dev-logs-mlflow dev-ps \
        prod-up prod-down deploy rollback clean-files clean-all help check-mlflow build-mlflow

COMPOSE_FILE		?= compose.yml
COMPOSE_FILE_PROD	?= compose.prod.yml
ENV_PROD			?= .env.prod

LOCAL_DIR_RAW      	?= ./data/raw
LOCAL_DIR_PROCESSED	?= ./data/processed

VERSION				?= $(IMAGE_VERSION)
ifeq ($(VERSION),)
  VERSION			:= latest
endif

MLFLOW_PORT			?= $(MLFLOW_PORT)
IMAGE_TRAIN			?= $(IMAGE_NAME_TRAINING)
IMAGE_SERVING		?= $(IMAGE_NAME_SERVING)
IMAGE_MLFLOW		?= $(IMAGE_NAME_MLFLOW)
IMAGE_DVC			?= $(IMAGE_NAME_DVC)

DOCKER_TRAINING_NAME ?= $(DOCKER_TRAINING_NAME)
DOCKER_MLFLOW_NAME ?= $(DOCKER_MLFLOW_NAME)

# ── 1. Gestión de conexion y descarga de archivos csv ─────────────────────────────────────────────
# Verifica si exiten las rutas de carpetas necesarias y las crea si no existen.
create-dirs:
	@echo "=== Verificando directorios necesarios para datos CSV ==="
	mkdir -p $(LOCAL_DIR_RAW)
	mkdir -p $(LOCAL_DIR_PROCESSED)

aws-dvc-up:
	@echo "=== Verificando estado del contenedor dvc_aws ==="
	@if [ -z "$$(docker compose -f $(COMPOSE_FILE) ps -q dvc_aws_service 2>/dev/null)" ]; then \
		echo "=== Levantando contenedor DVC-AWS ==="; \
		docker compose -f $(COMPOSE_FILE) up -d dvc_aws_service; \
	fi

download-aws: create-dirs aws-dvc-up
	@echo "=== Descargando datos desde AWS S3 dentro del contenedor ==="
	docker compose -f $(COMPOSE_FILE) exec dvc_aws_service aws s3 cp s3://$(AWS_S3_BUCKET)/$(AWS_RAW_FILE) data/raw/$(AWS_RAW_FILE)
	docker compose -f $(COMPOSE_FILE) exec dvc_aws_service aws s3 cp s3://$(AWS_S3_BUCKET)/$(AWS_PROCESSED_FILE) data/processed/$(AWS_PROCESSED_FILE)

download-dvc: create-dirs aws-dvc-up
	@echo "=== Descargando datos desde S3 utilizando DVC ==="
	docker compose -f $(COMPOSE_FILE) exec dvc_aws_service dvc pull --force

dvc-push: aws-dvc-up
	@echo "=== Subiendo artefactos a S3 mediante DVC ==="
	docker compose -f $(COMPOSE_FILE) exec dvc_aws_service dvc push
	@echo "=== Verificando estado de DVC ==="
	docker compose -f $(COMPOSE_FILE) exec dvc_aws_service dvc status

# ── 2. Gestión de MLflow ─────────────────────────────────────────────
check-mlflow:
	@STATUS=$$(docker inspect --format='{{.State.Health.Status}}' $(DOCKER_MLFLOW_NAME) 2>/dev/null || echo "not_found"); \
	if [ "$$STATUS" = "healthy" ]; then \
		echo "Contenedor $(DOCKER_MLFLOW_NAME) listo y saludable."; \
	else \
		echo "Contenedor $(DOCKER_MLFLOW_NAME) no disponible (Estado: $$STATUS). Levantando servicio..."; \
		docker compose -f $(COMPOSE_FILE) up -d --build mlflow_service; \
		echo "=== Esperando que el contenedor $(DOCKER_MLFLOW_NAME) pase el Healthcheck... ==="; \
		until [ "$$(docker inspect --format='{{.State.Health.Status}}' $(DOCKER_MLFLOW_NAME) 2>/dev/null)" = "healthy" ]; do \
			sleep 2; \
		done; \
		echo "Contenedor $(DOCKER_MLFLOW_NAME) listo y saludable para recibir metricas."; \
	fi

# ── 3. Construcción de Imágenes (Multi-Stage) ───────────────────────────────
check-training: check-mlflow
	@STATUS=$$(docker inspect --format='{{.State.Status}}' $(DOCKER_TRAINING_NAME) 2>/dev/null || echo "not_found"); \
	if [ "$$STATUS" = "running" ]; then \
		echo "Contenedor $(DOCKER_TRAINING_NAME) listo y corriendo."; \
	else \
		echo "Levantando contenedor de entrenamiento..."; \
		docker compose -f $(COMPOSE_FILE) up -d --build training_service; \
		echo "=== Esperando que el contenedor $(DOCKER_TRAINING_NAME) se inicie... ==="; \
		until [ "$$(docker inspect --format='{{.State.Status}}' $(DOCKER_TRAINING_NAME) 2>/dev/null)" = "running" ]; do \
			sleep 1; \
		done; \
		echo "Contenedor $(DOCKER_TRAINING_NAME) inicializado."; \
	fi

#PENDIENTE: Agregar target para construir imagen de inferencia ligera (serving) para Cloud Run
check-serving:
	@echo "=== Construyendo Imagen de Inferencia (Ligera / Cloud Run) ==="
	docker build \
		--target=serving \
		-t $(IMAGE_SERVING):$(VERSION) .

# ── 4. Pipeline de CI / CD Local (Entrenamiento y Validación) ──────────────────────────────────────────────────────
all: download-dvc check-training train test validate versions
	@echo "====================================================="
	@echo "Pipeline completado. Modelo Entrenado Exportado listo para API"
	@echo "====================================================="

train:
	@echo "=== [Paso 1/4] Procesando datos y entrenando modelo ==="
	docker exec -i $(DOCKER_TRAINING_NAME) python src/manage_data.py
	docker exec -i $(DOCKER_TRAINING_NAME) python src/train_model.py

test:
	@echo "=== [Paso 2/4] Ejecutando pruebas unitarias ==="
	docker exec -i $(DOCKER_TRAINING_NAME) pytest tests/test_data.py -v -s
	docker exec -i $(DOCKER_TRAINING_NAME) pytest tests/test_model.py -v -s
	docker exec -i $(DOCKER_TRAINING_NAME) pytest tests/test_pipeline.py -v -s

validate:
	@echo "=== [Paso 3/4] Quality Gate y Validación de Métricas ==="
	docker exec -i $(DOCKER_TRAINING_NAME) python src/validate_model.py

versions:
	@echo "=== [Paso 4/4] Registro de versión en MLflow ==="
	docker exec -i $(DOCKER_TRAINING_NAME) python src/manage_versions.py

# ── 5. Entorno de Desarrollo Local ──────────────────────────────────────
dev-up: download-dvc check-mlflow check-training
	@echo "Levantando modelo de entrenamiento..."
	docker compose -f $(COMPOSE_FILE) up -d training_service
	@echo "=== Entorno listo ==="
	@echo "  MODEL TRAINING: http://localhost:$(PORT_LOCAL)"
	@echo "  MLflow: http://localhost:$(MLFLOW_PORT)"

dev-down:
	docker compose -f $(COMPOSE_FILE) down -v
	@echo "=== Entorno detenido y volúmenes purgados ==="

dev-logs:
	docker compose -f $(COMPOSE_FILE) logs -f

dev-logs-api:
	docker compose -f $(COMPOSE_FILE) logs -f training_service

dev-logs-mlflow:
	docker compose -f $(COMPOSE_FILE) logs -f mlflow_service

dev-ps:
	docker compose -f $(COMPOSE_FILE) ps

# ── 6. Entorno Productivo Simulado ──────────────────────────────────────
prod-up: clean-all download-dvc
	@echo "=== Levantando entorno productivo ==="
	@eval $$(grep -v '^#' $(ENV_PROD) | xargs) && \
	docker compose --env-file $(ENV_PROD) -f $(COMPOSE_FILE_PROD) build --no-cache --pull && \
	docker compose --env-file $(ENV_PROD) -f $(COMPOSE_FILE_PROD) up -d

prod-down:
	docker compose -f $(COMPOSE_FILE_PROD) down -v
	@echo "=== Entorno detenido y volúmenes purgados ==="
	
# ── Flujo de Despliegue y Orquestación (deploy.sh) ───────────────────────────
## Flujo completo de despliegue manual encapsulado en bash
deploy:
	@chmod +x deploy.sh
	bash deploy.sh $(VERSION)

## Rollback de infraestructura a una etiqueta previa de Docker
rollback:
	@echo "=== Ejecutando Rollback a versión: $(VERSION) ==="
	docker compose -f $(COMPOSE_FILE) down
	docker tag $(IMAGE_TRAIN):$(VERSION) $(IMAGE_TRAIN):latest
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "=== Rollback completado ==="

# ── 7. Limpieza y Mantenimiento ────────────────────────────────────
clean-files:
	@echo "=== Limpiando cachés y temporales ==="
	rm -rf artifacts/* data/processed/* mlruns/* .pytest_cache htmlcov/ .coverage
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

clean-all: clean-files
	@echo "=== Purgando imágenes huérfanas y caché de Docker ==="
	docker image prune -f
	docker builder prune -f
	docker compose -f $(COMPOSE_FILE) down -v


# ── 8. Ayuda en Consola ──────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "===================================================================="
	@echo " Opciones de automatizacion del Makefile — Estructura MLOps "
	@echo "===================================================================="
	@echo "CI/CD local:"
	@echo "  make download-aws          — Descarga únicamente los CSVs de AWS S3"
	@echo "  make all                     — Ejecuta flujo completo (train + validate + docker)"
	@echo "  make train                   — Orquesta el ciclo de entrenamiento en src/"
	@echo "  make test                    — Ejecutar pruebas unitarias del directorio tests/"
	@echo "  make validate      		  — quality gate de métricas"
	@echo "  make versions      		  — versiones de modelos con MLFlow"
	@echo "  make docker                  — Construye la imagen de la API (contexto raíz)"
	@echo "  make build-mlflow            — Construye la imagen del servidor MLflow"
	@echo "  make down                    — Detiene todos los contenedores y purga volúmenes y cache"
	@echo ""
	@echo "Ambiente de desarrollo y contenedores:"
	@echo "  make dev-up                  — Levanta FastAPI ($(PORT_LOCAL)) y MLflow ($(MLFLOW_PORT))"
	@echo "  make dev-down                — Detiene el entorno y purga volúmenes locales"
	@echo "  make dev-logs-api            — Sigue los logs en tiempo real de la API"
	@echo "  make dev-logs-mlflow         — Sigue los logs del servidor de tracking"
	@echo "  make dev-ps                  — Muestra el estado del clúster local de Docker"
	@echo ""
	@echo "Ambiente de desarrollo y contenedores:"
	@echo "  make prod-up                  — Levanta FastAPI version productivo simulado"	
	@echo "  make prod-down                — Detiene el ambiente productivo simulado y purga volúmenes locales"
	@echo ""
	@echo "Despliegue y Control de Versiones:"
	@echo "  make deploy VERSION=1.0.0    — Ejecuta las fases de validación del script deploy.sh"
	@echo "  make rollback VERSION=1.0.0  — Reasigna tags de imagenes y levanta la versión previa"
	@echo "  make clean-files                   — Remueve basura de compilación y cachés de python"
	@echo "  make clean-images                  — Remueve imagenes de Docker no utilizadas"
	@echo "===================================================================="