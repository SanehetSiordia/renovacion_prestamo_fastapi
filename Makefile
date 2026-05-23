# Makefile — Pipeline CI/CD Local + Desarrollo (Renovación de Préstamo)

# Incluir variables del archivo .env de forma segura si existe
-include .env
export

.PHONY: all train validate docker \
        dev-up dev-down dev-logs dev-logs-api dev-logs-mlflow dev-ps \
        deploy rollback clean help

COMPOSE_FILE = compose.yml

VERSION ?= $(IMAGE_VERSION)
ifeq ($(VERSION),)
  VERSION := latest
endif

IMAGE_NAME_LOCAL ?= renovacion_prestamo-image

# ── Pipeline CI/CD local ──────────────────────────────────────────────────────
all: train validate docker
	@echo ""
	@echo "✓ Pipeline CI/CD local completado. Listo para git push."

train:
	@echo "=== Generando datos y entrenando modelo ==="
	python src/manage_data.py
	python src/train_model.py

validate:
	@echo "=== Validando métricas y Quality Gate ==="
	python src/validate_model.py

versions:
	@echo "=== Revision de Versiones en MLflow ==="
	python src/manage_versions.py

docker:
	@echo "=== Build de la imagen de la API ==="
	docker build \
		--build-arg APP_VERSION=$(APP_VERSION) \
		--build-arg PORT_LOCAL=$(PORT_LOCAL) \
		--build-arg PORT_REMOTE=$(PORT_REMOTE) \
		-t $(IMAGE_NAME_LOCAL):local .

# ── Ambiente Desarrollo (Docker Compose) ──────────────────────────────────────

## Levantar entorno completo desarrollo (FastAPI + MLflow)
dev-up:
	@echo "=== Levantando entorno de desarrollo para $(APP_NAME) ==="
	@echo "  Nota en Codespaces: los puertos $(PORT_LOCAL) y $(MLFLOW_PORT) se expondrán automáticamente."
	docker compose -f $(COMPOSE_FILE) up --build -d
	@echo "  Esperando que los servicios e hilos de salud inicien (120 s)..."
	sleep 120
	@echo ""
	@echo "=== Entorno listo ==="
	@echo "  API   : http://localhost:$(PORT_LOCAL)"
	@echo "  Docs  : http://localhost:$(PORT_LOCAL)/docs"
	@echo "  MLflow: http://localhost:$(MLFLOW_PORT)"

## Bajar entorno desarrollo y eliminar volúmenes persistentes de Docker
dev-down:
	docker compose -f $(COMPOSE_FILE) down -v
	@echo "=== Entorno detenido y volúmenes purgados ==="

## Ver logs en tiempo real de todos los servicios coordinados
dev-logs:
	docker compose -f $(COMPOSE_FILE) logs -f

## Ver logs específicos de la API (mapeado al servicio 'fastapi' del compose.yml)
dev-logs-api:
	docker compose -f $(COMPOSE_FILE) logs -f fastapi

## Ver logs específicos del servidor de tracking MLflow
dev-logs-mlflow:
	docker compose -f $(COMPOSE_FILE) logs -f mlflow

## Ver estado del clúster de contenedores
dev-ps:
	docker compose -f $(COMPOSE_FILE) ps


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
	@echo "=== Rollback completado hacia $(IMAGE_NAME_LOCAL):$(VERSION) ==="

# ── Limpieza Segura del Espacio de Trabajo ────────────────────────────────────
clean:
	@echo "=== Limpiando archivos temporales y cachés ==="
	rm -rf artifacts/ data/processed mlruns/ __pycache__ .coverage htmlcov/
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} +
	@echo "Limpieza completada."

# ── Ayuda en Consola ──────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "===================================================================="
	@echo " Opciones de automatización del Makefile — Estructura MLOps "
	@echo "===================================================================="
	@echo "CI/CD local:"
	@echo "  make all                     — Ejecuta flujo completo (train + validate + docker)"
	@echo "  make train                   — Orquesta el ciclo de entrenamiento en src/"
	@echo "  make validate      		  — quality gate de métricas"
	@echo "  make versions      		  — versiones de modelos con MLFlow"
	@echo "  make docker                  — Construye la imagen de la API (contexto raíz)"
	@echo ""
	@echo "Ambiente de desarrollo y contenedores:"
	@echo "  make dev-up                  — Levanta FastAPI ($(PORT_LOCAL)) y MLflow ($(MLFLOW_PORT))"
	@echo "  make dev-down                — Detiene el entorno y purga volúmenes locales"
	@echo "  make dev-logs-api            — Sigue los logs en tiempo real de la API"
	@echo "  make dev-logs-mlflow         — Sigue los logs del servidor de tracking"
	@echo "  make dev-ps                  — Muestra el estado del clúster local de Docker"
	@echo ""
	@echo "Despliegue y Control de Versiones:"
	@echo "  make deploy VERSION=1.0.0    — Ejecuta las fases de validación del script deploy.sh"
	@echo "  make rollback VERSION=1.0.0  — Reasigna tags de imágenes y levanta la versión previa"
	@echo "  make clean                   — Remueve basura de compilación y cachés de python"
	@echo "===================================================================="