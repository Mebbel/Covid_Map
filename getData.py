############################################################################
#
# Get data from the RKI
#
############################################################################

# Define necessary libraries
import requests
import pandas as pd
from sqlalchemy import create_engine
from datetime import datetime


# Settings ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define API call
url_landkreis = "https://services7.arcgis.com/mOBPykOjAyBO2ZKk/arcgis/rest/services/RKI_Landkreisdaten/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false&outSR=4326&f=json"


# Get Data ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the data
data_landkreis = requests.get(url_landkreis).json()

# Get the columns
columns_landkreis = [i['name'] for i in data_landkreis["fields"]]

# Extract the Data
df_landkreis = pd.DataFrame([i['attributes'] for i in data_landkreis['features']])

# Clean the data ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# numeric columns must be in English decimal notation
df_landkreis['cases7_per_100k_txt'] = [x.replace(',', '.') for x in df_landkreis['cases7_per_100k_txt']]
df_landkreis['cases7_per_100k_txt'] = df_landkreis['cases7_per_100k_txt'].astype(float)


# Connect to Database ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Create the engine
engine = create_engine('mysql://Write_User:123456@localhost/rki_covid')

# Connect with the engine
connection = engine.connect()

# Log the Request ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

connection.execute("INSERT INTO data_requests(DATE_REQUEST, NAME_OF_REQUEST, NUMBER_OF_ROWS) VALUES(%s, %s, %s)", 
(datetime.now().strftime("%d/%m/%Y %H:%M:%S"), "rki_landkreis", df_landkreis.shape[0])
)

# Get ID from Insert statement
id_request = connection.execute("SELECT MAX(ID_REQUEST) FROM data_requests").scalar()

# Add ID to df_landkreis
df_landkreis["ID_REQUEST"] = id_request

# Write the data ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
try:
    df_landkreis.to_sql(name = "rki_landkreis", schema = "rki_covid", con = connection, if_exists = "append", index = False)
except:
    df_error = pd.DataFrame.from_dict({"ID_REQUEST": id_request, "COMMENT": "Error appending data to rki_landkreis"})
    df_error.to_sql(name = "log", schema = "rki_covid", con = connection, if_exists = "append", index = False)


# Close the connection ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
connection.close()
engine.dispose()

