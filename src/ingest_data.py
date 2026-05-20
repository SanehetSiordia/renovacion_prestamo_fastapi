""" Etapa 1 — Ingestión y tratamiento de datos. 
Entrada : data/raw/raw_renovacion_prestamo.csv.dvc
Salida  : data/processed/processed_renovacion_prestamo.csv.dvc
""" 

import sys
import logging

from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import config as C
import pandas as pd
import numpy as np 

logging.basicConfig(level=logging.INFO,    format='%(asctime)s | INGEST | %(levelname)s | %(message)s',    
                    datefmt='%H:%M:%S') 
log = logging.getLogger(__name__)

def renombrar_columnas(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    for col, col_nueva in C.COLUMNAS_RENOMBRAR.items():
        if col in df.columns:
            df = df.rename(columns={col: col_nueva})
            log.info(f'Columna renombrada: {col} -> {col_nueva}')
    return df

def imputar_columnas_negativas(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    for col in C.COLUMNAS_IMPUTAR_NEGATIVOS:
        df[col] = np.maximum(0, df[col])
        log.info(f'Columna con negativos imputados a 0: {col}')
    return df

def transformar_columnas(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    for col in C.COLUMNAS_TRANSFORMAR_LOG:
        new_col_name = f'{col}_LOG'
        if col in df.columns:
            df[new_col_name] = np.log1p(df[col])
            log.info(f'Columna transformada con log1p: {col} -> {new_col_name}')
    return df

def imputar_nulos_sampling_aleatorio(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    for col in C.COLUMNAS_NULOS_SAMPLING_ALEATORIO:        
        if col in df.columns:
            
            null_indices = df[col].isnull()            
            random_imputed_values=np.random.uniform(max(0,(df[col].mean()-df[col].std())),
                                                    (df[col].mean()+df[col].std()), 
                                                    null_indices.sum())            
            df.loc[null_indices, col] = random_imputed_values
            log.info(f'Columna con nulos imputados con Sampling Aleatorio: {col}')
            log.info(f'Nulos restantes en {col}: {df[col].isna().sum()}')
    return df

def imputar_nulos_mediana(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    for col in C.COLUMNAS_NULOS_MEDIANA:        
        if col in df.columns:            
            df[col] = df[col].fillna(df[col].median())
            log.info(f'Columna con nulos imputados con la Mediana: {col}')
            log.info(f'Nulos restantes en {col}: {df[col].isna().sum()}')
    return df

def imputar_nulos_categorias(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    for col in C.COLUMNAS_NULOS_CATEGORIAS:        
        if col in df.columns:            
            df[col] = df[col].fillna(df[col].mode()[0])
            log.info(f'Columna de variables categoricas con nulos imputados: {col}')
            log.info(f'Nulos restantes en {col}: {df[col].isna().sum()}')
    return df

def run() -> pd.DataFrame:    
    log.info('=== ETAPA 1: Ingestión y tratamientos de datos ===')    
    if not C.RAW_DATA_PATH.exists():        
        raise FileNotFoundError(f'Dataset no encontrado: {C.RAW_DATA_PATH}')    
    df = pd.read_csv(C.RAW_DATA_PATH, sep=';')
    log.info('Cargado: %d filas x %d columnas', *df.shape)

    df = renombrar_columnas(df)
    df = imputar_columnas_negativas(df)
    df = transformar_columnas(df)
    df = imputar_nulos_sampling_aleatorio(df)
    df = imputar_nulos_mediana(df)
    df = imputar_nulos_categorias(df) 
    #One-Hot Encoding CATEGORICAS
    #df = winsorizar(df)
    #df = imputar(df)    
    #validar_salida(df)    
    #df.to_csv(C.CLEAN_DATA_PATH, index=False)    
    #log.info('Artefacto guardado: %s', C.CLEAN_DATA_PATH)

    log.info('=== ETAPA 1 COMPLETADA ===')    
    return df

if __name__ == '__main__':    
    run()