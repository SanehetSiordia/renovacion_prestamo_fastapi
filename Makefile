# Makefile — Pipeline CI/CD Local + Desarrollo (Renovación de Préstamo)

-include .env
export

.PHONY: create-dirs download-data download-dvc dvc-push\
		all train validate docker \
		dev-up dev-down dev-logs dev-logs-api dev-logs-mlflow dev-ps \
        deploy rollback clean help check-mlflow mlflow \
		prod-up prod-down

COMPOSE_FILE = compose.yml
COMPOSE_FILE_PROD = compose.prod.yml
ENV_PROD = .env.prod

LOCAL_DIR_RAW ?= ./data/raw
LOCAL_DIR_PROCESSED ?= ./data/processed

VERSION ?= $(IMAGE_VERSION)
ifeq ($(VERSION),)
  VERSION := latest
endif

IMAGE_NAME_LOCAL ?= $(IMAGE_NAME)

# ── Conexion y descarga de archivos csv ─────────────────────────────────────────────
# Verifica si exiten las rutas de carpetas necesarias y las crea si no existen.
create-dirs:
	@echo "=== Verificando directorios necesarios para datos CSV ==="
	mkdir -p $(LOCAL_DIR_RAW)
	mkdir -p $(LOCAL_DIR_PROCESSED)

aws-dvc-up:
	@echo "=== Verificando estado del contenedor dvc_aws ==="
	@if [ -z "$$(docker compose -f $(COMPOSE_FILE) ps -q dvc_aws)" ]; then \
		echo "=== Contenedor no encontrado o apagado. Levantando... ==="; \
		docker compose -f $(COMPOSE_FILE) up -d dvc_aws; \
	else \
		echo "=== El contenedor dvc_aws ya esta levantado y en ejecucion. ==="; \
	fi

download-aws: create-dirs aws-dvc-up
	@echo "=== Descargando datos desde AWS S3 dentro del contenedor ==="
	docker compose -f $(COMPOSE_FILE) exec dvc_aws aws s3 cp s3://$(AWS_S3_BUCKET)/$(AWS_RAW_FILE) data/raw/$(AWS_RAW_FILE)
	docker compose -f $(COMPOSE_FILE) exec dvc_aws aws s3 cp s3://$(AWS_S3_BUCKET)/$(AWS_PROCESSED_FILE) data/processed/$(AWS_PROCESSED_FILE)

download-dvc: create-dirs aws-dvc-up
	@echo "=== Descargando datos desde S3 utilizando DVC ==="
	docker compose -f $(COMPOSE_FILE) exec dvc_aws dvc pull --force

dvc-push: aws-dvc-up
	@echo "=== Subiendo artefactos a S3 mediante DVC ==="
	docker compose -f $(COMPOSE_FILE) exec dvc_aws dvc push
	@echo "=== Verificando estado de DVC ==="
	docker compose -f $(COMPOSE_FILE) exec dvc_aws dvc status

# ── Validación Dinamica de MLflow ─────────────────────────────────────────────
# Verifica si el contenedor ya esta saludable. Si no, invoca el target mlflow.
check-mlflow:
	@STATUS=$$(docker inspect --format='{{.State.Health.Status}}' $(DOCKER_MLFLOW_NAME) 2>/dev/null || echo "not_found"); \
	if [ "$$STATUS" = "healthy" ]; then \
		echo "  MLflow ya esta activo y saludable. Continuando..."; \
	else \
		echo "⚠️ MLflow no esta listo (Estado: $$STATUS). Inicializando..."; \
		$(MAKE) mlflow; \
	fi

# Verifica si el contenedor de la API ya existe y esta corriendo
check-api: download-dvc
	@STATUS=$$(docker inspect --format='{{.State.Status}}' $(DOCKER_FASTAPI_NAME) 2>/dev/null || echo "not_found"); \
	if [ "$$STATUS" = "running" ]; then \
		echo "  El contenedor de la API ($(DOCKER_FASTAPI_NAME)) ya esta desplegado y corriendo."; \
	else \
		echo "El contenedor de la API no esta activo (Estado: $$STATUS). Construyendo..."; \
		$(MAKE) docker; \
		echo "=== Desplegando API (FastAPI) ==="; \
		docker compose -f $(COMPOSE_FILE) up -d fastapi; \
	fi

# ── Pipeline CI/CD local ──────────────────────────────────────────────────────
all: download-dvc train test validate versions dvc-push docker 
	@echo "✓ Pipeline CI/CD local completado exitosamente de forma aislada."

train: check-mlflow check-api
	@echo "=== Generando datos y entrenando modelo ==="
	docker exec -i $(DOCKER_FASTAPI_NAME) python src/manage_data.py
	docker exec -i $(DOCKER_FASTAPI_NAME) python src/train_model.py

test:
	@echo "=== Tests unitarios con pytest ==="
	docker exec -i $(DOCKER_FASTAPI_NAME) pytest tests/test_data.py -v -s
	docker exec -i $(DOCKER_FASTAPI_NAME) pytest tests/test_model.py -v -s
	docker exec -i $(DOCKER_FASTAPI_NAME) pytest tests/test_pipeline.py -v -s

validate: check-api
	@echo "=== Validando metricas y Quality Gate ==="
	docker exec -i $(DOCKER_FASTAPI_NAME) python src/validate_model.py

versions: check-mlflow check-api
	@echo "=== Revision de Versiones en MLflow ==="
	docker exec -i $(DOCKER_FASTAPI_NAME) python src/manage_versions.py

docker:
	@echo "=== Verificando existencia de la imagen de la API ==="
	@if docker image inspect $(IMAGE_NAME_LOCAL):$(VERSION) >/dev/null 2>&1; then \
		echo "La imagen $(IMAGE_NAME_LOCAL):$(VERSION) ya existe. Saltando docker build."; \
	else \
		echo "=== Build de la imagen de la API ==="; \
		docker build \
			--provenance=false \
			--build-arg APP_VERSION=$(APP_VERSION) \
			--build-arg PORT_LOCAL=$(PORT_LOCAL) \
			--build-arg PORT_REMOTE=$(PORT_REMOTE) \
			-t $(IMAGE_NAME_LOCAL):$(VERSION) .; \
	fi

mlflow:
	@echo "=== Iniciando Servidor MLflow de forma independiente ==="
	docker compose -f $(COMPOSE_FILE) up -d mlflow
	@echo "=== Esperando que MLflow pase el Healthcheck... ==="
	@until [ "$$(docker inspect --format='{{.State.Health.Status}}' $(DOCKER_MLFLOW_NAME))" = "healthy" ]; do \
		echo "MLflow esta iniciando... esperando 3 segundos mas."; \
		sleep 3; \
	done
	@echo "MLflow arriba y saludable."

down:
	@echo "=== Deteniendo todos los contenedores ==="
	docker builder prune -a -f
	docker compose -f $(COMPOSE_FILE) down -v
	@echo "=== Todos los contenedores detenidos ==="

# ── Ambiente Desarrollo (Docker Compose) ──────────────────────────────────────

dev-up: download-dvc
	@echo "=== Levantando entorno de desarrollo para $(APP_NAME) ==="
	docker compose -f $(COMPOSE_FILE) up -d mlflow
	@echo "Esperando inicialización de MLflow..."
	@until [ "$$(docker inspect --format='{{.State.Health.Status}}' $(DOCKER_MLFLOW_NAME))" = "healthy" ]; do sleep 2; done
	@echo "Levantando servicio FastAPI..."
	docker compose -f $(COMPOSE_FILE) up -d fastapi
	@echo "=== Entorno listo ==="
	@echo "  API   : http://localhost:$(PORT_LOCAL)"
	@echo "  MLflow: http://localhost:$(MLFLOW_PORT)"

dev-down:
	docker compose -f $(COMPOSE_FILE) down -v
	@echo "=== Entorno detenido y volúmenes purgados ==="

dev-logs:
	docker compose -f $(COMPOSE_FILE) logs -f

dev-logs-api:
	docker compose -f $(COMPOSE_FILE) logs -f fastapi

dev-logs-mlflow:
	docker compose -f $(COMPOSE_FILE) logs -f mlflow

dev-ps:
	docker compose -f $(COMPOSE_FILE) ps

# ── Ambiente Productivo - SOLO FAST API CON MODELO (Docker Compose) ──────────────────────────────────────
prod-up: download-data
	@echo "=== Levantando entorno productivo ==="
	docker builder prune -a -f
	@eval $$(grep -v '^#' $(ENV_PROD) | xargs) && \
	docker compose --env-file $(ENV_PROD) -f $(COMPOSE_FILE_PROD) build --no-cache --pull && \
	docker compose --env-file $(ENV_PROD) -f $(COMPOSE_FILE_PROD) up -d

prod-down:
	docker builder prune -a -f
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
	docker tag $(IMAGE_NAME_LOCAL):$(VERSION) $(IMAGE_NAME_LOCAL):latest
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "=== Rollback completado ==="

# ── Limpieza Segura del Espacio de Trabajo ────────────────────────────────────
clean-files:
	@echo "=== Limpiando archivos temporales y cachés ==="
	rm -rf artifacts/* data/processed/* mlruns/* __pycache__ .coverage htmlcov/
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} +
	@echo "Limpieza completada."

clean-images:
	@echo "=== Limpiando imagenes de Docker no utilizadas ==="
	docker image prune -a -f
	@echo "Limpieza de imagenes completada."

# ── Ayuda en Consola ──────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "===================================================================="
	@echo " Opciones de automatizacion del Makefile — Estructura MLOps "
	@echo "===================================================================="
	@echo "CI/CD local:"
	@echo "  make download-data           — Descarga únicamente los CSVs de AWS S3"
	@echo "  make all                     — Ejecuta flujo completo (train + validate + docker)"
	@echo "  make train                   — Orquesta el ciclo de entrenamiento en src/"
	@echo "  make test                    — Ejecutar pruebas unitarias del directorio tests/"
	@echo "  make validate      		  — quality gate de métricas"
	@echo "  make versions      		  — versiones de modelos con MLFlow"
	@echo "  make docker                  — Construye la imagen de la API (contexto raíz)"
	@echo "  make mlflow                  — Inicia el servidor MLflow"
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