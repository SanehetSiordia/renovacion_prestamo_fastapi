# renovacion_prestamo_fastapi
Analisis de caso de negocio de renovacion de prestamo con algoritmos de machine learning utilizando fastapi dockerizado
Proyecto con arquitectura 100% Hermetica con Docker.
---

## 🛠️ Stack Tecnológico

![Python](https://img.shields.io/badge/Python-3.10+-blue?logo=python)
![Git](https://img.shields.io/badge/Git-control%20de%20versiones-orange?logo=git)
![Docker](https://img.shields.io/badge/Docker-contenedores-blue?logo=docker)
![MLflow](https://img.shields.io/badge/MLflow-tracking-lightblue?logo=mlflow)
![FastAPI](https://img.shields.io/badge/FastAPI-serving-green?logo=fastapi)

---

## ⚙️ Requisitos Previos

- Python 3.10+
- Cuenta GitHub
- Docker
- VS Code
- Make

### Instalación del entorno

```bash
# Clonar el repositorio
git clone https://github.com/SanehetSiordia/renovacion_prestamo_fastapi.git
cd renovacion_prestamo_fastapi
# Instalar AWS CLI con el comando en Powershell:
irm https://awscli.amazonaws.com/v2/install.ps1 | iex 
Documentacion: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
#Verificar instalacion de AWS CLI:
aws --version
#Instalar DVC en equipo local con comando:
winget install --id Iterative.DVC
#Verificar DVC instalado:
dvc --version
# Ejecutar permisos para versionamiento con DVC en la terminal:
chmod +x entrypoint.sh
# Instalar Make con el comando en CMD:
winget install ezwinports.make
# Comprobar Make instalado con:
make --version
# Ejecutar comando Make
Make all
#Validar entornos virtuales desde Browser:
http://localhost:8085/          --FastApi Home
http://localhost:8085/docs      --FastApi OpenApi
http://localhost:8085/health    --FastApi Healthchek
http://localhost:5000/          --MLFLOW GUI
#Detener todo los contenedores y purgar cache con:
make down
#Para mayor informacion ejecutar comando make:
make help
```
---

## Plan a Futuro

- Agregar Ingesta Continua con Auto Loader con PySpark y Databricks

---
