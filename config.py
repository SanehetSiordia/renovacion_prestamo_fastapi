"""
config.py — Configuración centralizada del pipeline MLOps Renovacion de Prestamo

Uso:
    import config as C
    df = pd.read_csv(C.RAW_DATA_PATH, sep=';')
"""
import os
from pathlib import Path

# ── Directorios ──────────────────────────────────────────────────────────────
ROOT_DIR      = Path(__file__).parent
DATA_RAW_DIR      = ROOT_DIR / 'data/raw'
DATA_PROCESSED_DIR      = ROOT_DIR / 'data/processed'

# ── Archivos ─────────────────────────────────────────────────────────────────
RAW_DATA_PATH   = DATA_RAW_DIR      / 'raw_renovacion_prestamo.csv'
PROCESSED_DATA_PATH = DATA_PROCESSED_DIR / 'processed_renovacion_prestamo.csv'

# ── Columnas ─────────────────────────────────────────────────────────────────
TARGET     = 'FLAG_VENTA'
COLUMNAS_RENOMBRAR = {
    "LINEA_RENOVADO": "Linea_Renovado",
    "PLAZO_RENOVADO": "Plazo_Renovado",
    "USO_LINEA_TOTAL_TC_T2": "Uso_Linea",
    "USO_TRIM_LINEA_BBVA": "Uso_TrimLinea",
    "NR_ENTIDADES_TOTAL_T2": "Nro_Entidades",
    "DIFF_NRO_ENTIDA_TOTALES_T2_T12": "Dif_Entidades",
    "SDO_CONSUMO_T2": "Saldo_Consumo",
    "RESENCIA_OFERTA_PLD_RENOVADO": "Meses_oferta",
    "Ahorro_Sldo_Bco_T1": "Ahorro",
    "PConsumo_Sldo_Bco_T1": "Prestamo_vigente",
    "SDO_BCO_tot_sm_pasivo_Bco_6M": "Promed_6Mdeuda",
    "FLAG_LIMA_PROVINCIA": "Flag_LimProv",
    "CUBRIR_DEUDA_CONSUMO_SF_RENOVA_PLD": "Deuda_Cubierta%",
}

# ── Preprocesamiento ──────────────────────────────────────────────────────────
COLUMNAS_IMPUTAR_NEGATIVOS = ['Ahorro','Prestamo_vigente','Promed_6Mdeuda']

COLUMNAS_TRANSFORMAR_LOG = ['Uso_Linea',
                            'Uso_TrimLinea',
                            'Saldo_Consumo',
                            'SUELDO_ESTIMADO',
                            'ANTIGUEDAD_MES',
                            'Linea_Renovado',
                            'Ahorro',
                            'Prestamo_vigente',
                            'Promed_6Mdeuda',
                            'SUELDO_ESTIMADO',
                            'Deuda_Cubierta%']

COLUMNAS_NULOS_SAMPLING_ALEATORIO=['Uso_TrimLinea_LOG','Uso_Linea_LOG','Meses_oferta']

COLUMNAS_NULOS_MEDIANA=['Saldo_Consumo_LOG','SUELDO_ESTIMADO_LOG','ANTIGUEDAD_MES_LOG','EDAD']

COLUMNAS_NULOS_CATEGORIAS = ['REGION','SEXO','EST_CIVIL']