import pandas as pd
from sqlalchemy import create_engine
import mysql.connector

### Conexión a la Base de Datos Local

mydb = mysql.connector.connect(
  host="localhost",
  user="root",
  password="123456789",
  database="deliveryapp"
)

### Creación de Tablas: venta, descuento y cliente
### Primero se borra toda la información de las tablas existentes, ya que se considera el documento de Excel como la información real
### Solo la tabla venta cuenta con Foreign Key

mycursor = mydb.cursor()

for nombre_tabla in ['venta', 'descuento', 'cliente']:
    try:
        sql = f"DROP TABLE {nombre_tabla}"
        mycursor.execute(sql)
    except:
        pass

sql = """   CREATE TABLE cliente (
            id int NOT NULL AUTO_INCREMENT,
            nombre varchar(255) NOT NULL,
            edad int NOT NULL,
            genero char(1) NOT NULL,
            PRIMARY KEY (id)
)"""
mycursor.execute(sql)

sql = """   CREATE TABLE descuento (
	        id int NOT NULL AUTO_INCREMENT,
            descuento float NOT NULL,
            PRIMARY KEY(id)
)"""
mycursor.execute(sql)

sql = """   CREATE TABLE venta (
            id int NOT NULL AUTO_INCREMENT,
            fecha_venta date NOT NULL,
            cliente_id int NOT NULL,
            cantidad int NOT NULL,
            precio_unitario float NOT NULL,
            descuento_id int NOT NULL,
            prioridad varchar(50),
            medio_envio varchar(50),
            segmento varchar(50),
            provincia varchar(50),
            PRIMARY KEY(id),
            FOREIGN KEY(cliente_id) REFERENCES cliente(id),
            FOREIGN KEY(descuento_id) REFERENCES descuento(id)
)"""
mycursor.execute(sql)
    
mydb.commit()

### Organización de la información de Excel utilizando pandas y carga de los datos al servidor de MySQL

engine = create_engine('mysql://root:123456789@localhost/deliveryapp')

excel_name = 'data_base.xlsx'

df = pd.read_excel(excel_name, sheet_name='Cliente')
df.to_sql('cliente', con=engine, if_exists='append', index=False)

df = pd.read_excel(excel_name, sheet_name='Descuento')
df.to_sql('descuento', con=engine, if_exists='append', index=False)
print(df.head())

df = pd.read_excel(excel_name, sheet_name='Ventas')
print(df.head())
df.rename(columns= {    'Fecha de Venta': 'fecha_venta',
                        'ClienteID': 'cliente_id',
                        'Precio Unitario': 'precio_unitario',
                        'DescuentoID': 'descuento_id',
                        'Prioridad': 'prioridad',
                        'Medio de Envío': 'medio_envio',
                        'Segmento': 'segmento',
                        'Provincia': 'provincia'
                        }, inplace= True)
df.to_sql('venta', con=engine, if_exists='append', index=False)