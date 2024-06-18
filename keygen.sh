#!/bin/bash

echo "----------------PASO 1--------------------"
echo "Verificar los argumentos"
# Verifica si se han proporcionado los argumentos necesarios
if [ "$#" -ne 4 ]; then
    echo "Uso: $0 <nombre> <contraseña> <puerto_p2p> <directorio_home>"
    exit 1
fi

echo "----------------PASO 2--------------------"
echo "Asignar variables a partir de los argumentos"
# Asignación de variables a partir de los argumentos
MONIKER=$1
PASSWORD=$2
P2P_PORT=$3
HOME_DIR=$4
VAULT_NAME="default"
CHANNEL_FILE="id_channel.txt"
OUTPUT_FILE="../output_keygen_${MONIKER}.txt"  # Archivo de salida específico para cada parte

echo "----------------PASO 3--------------------"
echo "Comprobar que 'go' está instalado en la ruta especificada"
# Verifica si 'go' está instalado en la ruta especificada
if [ ! -f /usr/local/go/bin/go ]; then
    echo "'go' no está instalado en /usr/local/go/bin/go. Instálalo primero."
    exit 1
fi

echo "----------------PASO 4--------------------"
echo "Agregar 'go' al PATH temporalmente para esta sesión"
# Agrega 'go' al PATH temporalmente para esta sesión
export PATH=$PATH:/usr/local/go/bin

echo "----------------PASO 5--------------------"
echo "Clonar y construir el binario de TSS si no está ya"
# Clona y construye el binario de TSS si no está ya
TSS_REPO="https://github.com/ivansjg/tss"
TSS_DIR="tss"

echo "Clonar el repositorio si no existe el directorio"
# Clona el repositorio si no existe el directorio
if [ ! -d "$TSS_DIR" ]; then
    git clone $TSS_REPO
fi

echo "Cambiar al directorio del repositorio"
# Cambia al directorio del repositorio
cd $TSS_DIR

echo "Construir el binario del proyecto"
# Construye el binario del proyecto
/usr/local/go/bin/go build

echo "----------------PASO 6--------------------"
echo "Inicializar la party MPC"
# Inicializa la party MPC
./tss init --home ./${HOME_DIR} --vault_name $VAULT_NAME --moniker $MONIKER --password $PASSWORD --p2p.listen "/ip4/127.0.0.1/tcp/$P2P_PORT"

echo "----------------PASO 7--------------------"
echo "Crear un canal y guardar el ID del canal si no existe"
# Crea un canal y guarda el ID del canal si no existe
if [ ! -f "../$CHANNEL_FILE" ]; then
    CHANNEL_ID=$(./tss channel --channel_expire 120 | grep "channel id" | awk '{print $3}')
    echo $CHANNEL_ID > "../$CHANNEL_FILE"
else
    CHANNEL_ID=$(cat "../$CHANNEL_FILE")
fi

echo "----------------PASO 8--------------------"
echo "Definir las direcciones de los peers para la conexión P2P"
# Define las direcciones de los peers para la conexión P2P
P2P_PEER_ADDRS=$(IFS=, ; echo "/ip4/127.0.0.1/tcp/54964,/ip4/127.0.0.1/tcp/54965,/ip4/127.0.0.1/tcp/54966")

echo "Realizar el keygen para la party y guardar la salida en un archivo"
# Realiza el keygen para la party y guarda la salida en un archivo
./tss keygen --home ./${HOME_DIR} --vault_name $VAULT_NAME --parties 3 --threshold 1 --password $PASSWORD --channel_password $PASSWORD --channel_id $CHANNEL_ID --p2p.peer_addrs "$P2P_PEER_ADDRS" > "$OUTPUT_FILE" 2>&1

echo "----------------PASO 9--------------------"
echo "Extraer la clave pública comprimida y la dirección de eth desde el archivo de salida"
# Extrae la clave pública comprimida y la dirección de eth desde el archivo de salida
PUB_KEY_COMPRESSED=$(grep -oP 'public key compressed in hex: \K[0-9a-fA-F]+' "$OUTPUT_FILE")
VAULT_ADDRESS=$(grep -oP 'bech32 address is: \K0x[0-9a-fA-F]+' "$OUTPUT_FILE")

echo "Clave pública comprimida: $PUB_KEY_COMPRESSED"
echo "Dirección del vault: $VAULT_ADDRESS"

echo "----------------PASO 10--------------------"
echo "Verificar si se obtuvieron correctamente la clave pública y la dirección"
# Verifica si se obtuvieron correctamente la clave pública y la dirección
if [ -z "$PUB_KEY_COMPRESSED" ] || [ -z "$VAULT_ADDRESS" ]; then
    echo "Error: No se pudo obtener la clave pública o la dirección del vault."
    exit 1
fi

echo "----------------PASO 11--------------------"
echo "Guardar la clave pública y la dirección en archivos para facilitar el uso"
# Guarda la clave pública y la dirección en archivos para su uso posterior
echo "$PUB_KEY_COMPRESSED" > "../pub_key_compressed.txt"
echo "$VAULT_ADDRESS" > "../vault_address.txt"

echo "Proceso de keygen completado. La clave pública y la dirección se han guardado."
