import os
from fastapi import FastAPI

app = FastAPI()
#Modificacion de openapi FastApi
app.title ="Renovacion Prestamo con Fast API"
app.version= "0.0.1-SNAPSHOT"

@app.get('/')
def home():
    return "Hola Mundo - Renovacion Prestamo con Fast API"