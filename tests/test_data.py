"""tests/test_data.py — Tests para revisar el dataset procesad."""
import sys
import logging

from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import config as C
import pandas as pd

logging.basicConfig(level=logging.INFO, format='%(asctime)s | TEST_DATA | %(levelname)s | %(message)s',
                    datefmt='%H:%M:%S')

log = logging.getLogger(__name__)

def test_generate_has_correct_columns():
    """El dataset debe tener todas las columnas esperadas."""

    if not C.PROCESSED_DATA_PATH.exists():        
        raise FileNotFoundError(f'Dataset no encontrado: {C.PROCESSED_DATA_PATH}')    
    df = pd.read_csv(C.PROCESSED_DATA_PATH, sep=',')
    log.info(f'Cargado Dataframe: {df.shape[0]} filas x {df.shape[1]} columnas')

    
    for col in C.FEATURES + [C.TARGET]:
        assert col in df.columns, f"Columna faltante: {col}"