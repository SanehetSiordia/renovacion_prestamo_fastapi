import os
import sys
import logging
import json
import pickle
import skops.io as sio
import pandas as pd

from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import config as C

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format="%(asctime)s | PREDICTOR API | %(levelname)s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

MODEL_PATH   = C.MODEL_PKL_PATH
METRICS_PATH = C.METRICS_PATH

FEATURES = C.FEATURES
UMBRAL   = C.UMBRAL_MIN


class Predictor:
    def __init__(self, model=None):
        self.modelo = model
        self.metricas = {}

    def cargar(self) -> None:
        if not MODEL_PATH.exists():
            raise FileNotFoundError(
                f"Modelo no encontrado: {MODEL_PATH}. "
                "Asegúrate de que el servicio trainer completó exitosamente."
            )
        
        if not METRICS_PATH.exists():
            raise FileNotFoundError(
                f"Metricas del modelo no encontrado: {METRICS_PATH}. "
                "Asegúrate de que el servicio trainer completó exitosamente."
            )
            
        with open(MODEL_PATH, "rb") as f:
            self.modelo = pickle.load(f)

        if METRICS_PATH.exists():
            with open(METRICS_PATH) as f:
                self.metricas = json.load(f)

        log.info(f"Modelo cargado: {type(self.modelo).__name__}")
        log.info(f"Recall en entrenamiento: {self.metricas.get('metricas_evaluacion', {}).get('recall', 0)}")

    def predecir(self, datos: dict) -> dict:
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
