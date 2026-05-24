import os
import sys
import logging
import json
import pickle
import pandas as pd

from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import config as C
class DummyModel:
    def predict_proba(self, X):        
        return [[1.0, 0.0]]

log = logging.getLogger(__name__)

MODEL_PATH   = C.MODEL_PKL_PATH
METRICS_PATH = C.METRICS_PATH
FEATURES = C.FEATURES
UMBRAL   = C.UMBRAL_MIN

class Predictor:
    def __init__(self, model=None):
        self.modelo = model
        self.metricas = {}
        self.inicializado = False

    def cargar(self) -> None:
        # Cargar Modelo SI ESQUE EXISTE
        if MODEL_PATH.exists() and METRICS_PATH.exists():
            try:
                with open(MODEL_PATH, "rb") as f:
                    self.modelo = pickle.load(f)
                with open(METRICS_PATH) as f:
                    self.metricas = json.load(f)
                
                self.inicializado = True
                log.info(f"✓ Modelo real cargado exitosamente: {type(self.modelo).__name__}")
                return
            except Exception as e:
                log.warning(f"Error leyendo los archivos reales, usando contingencia: {str(e)}")

        # Cargar Clase SI EL MODELO NO EXISTE
        log.warning(f"⚠️ {MODEL_PATH} no encontrado. Inicializando con Modelo Dummy para permitir Pipelines CI/CD.")
        self.modelo = DummyModel()
        self.metricas = {
            "metricas_evaluacion": {"recall": 0.0},
            "info": "Modo de contingencia: Esperando ejecución del pipeline de entrenamiento."
        }
        self.inicializado = False

    def predecir(self, datos: dict) -> dict:
        
        if not self.inicializado:
            self.cargar()

        if self.modelo is None:
            raise RuntimeError("Modelo no cargado. Llama a cargar() primero.")
        
        datos_alineados = {f: datos.get(f, 0) for f in FEATURES}
        X = pd.DataFrame([datos_alineados])[FEATURES]
        proba = float(self.modelo.predict_proba(X)[0][1])

        return {
            "score_riesgo":      round(proba, 4),
            "decision":          "USUARIO PARA RENOVACION DETECTADO" if proba >= UMBRAL else "NORMAL",
            "probabilidad_pico": round(proba, 4),
            "umbral_usado":      UMBRAL,
            "modelo":            type(self.modelo).__name__,
        }

predictor = Predictor()
