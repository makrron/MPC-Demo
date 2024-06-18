#!/bin/bash

echo "----------------PASO 1--------------------"
echo "Verificar los argumentos"
# Verifica los argumentos
if [ "$#" -ne 5 ]; then
    echo "Uso: $0 <nombre> <contraseña> <directorio_party> <direccion_envio> <cantidad>"
    exit 1
fi

echo "----------------PASO 2--------------------"
echo "Asignar variables a partir de los argumentos"
# Asignación de variables a partir de los argumentos
MONIKER=$1
PASSWORD=$2
DIR_PARTY=$3
DEST_ADDRESS=$4
AMOUNT=$5
VAULT_NAME="default"
CHANNEL_FILE="id_channel.txt"
SIGN_OUTPUT_FILE="../output_sign_${MONIKER}.txt"  # Archivo de salida específico para cada party
JAR_FILE="../ethereum_tool.jar"  # Ruta al archivo .jar
RAW_TX_FILE="../output_UnsignedRawEthereumTx.txt"  # Archivo temporal para guardar el hash sin firmar
SIGNED_TX_FILE="../output_SignedRawEthereumTx.txt"  # Archivo para guardar la transacción firmada
FINAL_TX_FILE="../output_FinalRawEthereumTx.txt"  # Archivo para guardar la transacción final

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
echo "Leer la clave pública y la dirección del vault desde los archivos guardados"
# Lee la clave pública y la dirección del vault desde los archivos guardados
if [ ! -f "../pub_key_compressed.txt" ] || [ ! -f "../vault_address.txt" ]; then
    echo "Error: No se encontraron los archivos de la clave pública y la dirección del vault. Ejecuta primero el script de keygen."
    exit 1
fi

PUB_KEY_COMPRESSED=$(cat "../pub_key_compressed.txt")
VAULT_ADDRESS=$(cat "../vault_address.txt")

echo "Clave pública comprimida: $PUB_KEY_COMPRESSED"
echo "Dirección del vault: $VAULT_ADDRESS"
echo "Dirección de envío: $DEST_ADDRESS"
echo "Cantidad: $AMOUNT"

echo "----------------PASO 7--------------------"
echo "Verificar y ajustar permisos del archivo .jar si es necesario"
# Verifica si el archivo .jar existe
if [ ! -f "$JAR_FILE" ]; then
    echo "Error: No se encontró el archivo $JAR_FILE. Verifica la ruta."
    exit 1
fi

# Verifica y ajusta permisos si es necesario
if [ ! -r "$JAR_FILE" ] || [ ! -x "$JAR_FILE" ]; then
    echo "Ajustando permisos del archivo .jar"
    chmod +rx "$JAR_FILE"
fi

echo "----------------PASO 8--------------------"
echo "Generar el hash a firmar usando la herramienta externa .jar con timeout"
if [ ! -f "$RAW_TX_FILE" ]; then
    # Genera el hash a firmar usando la herramienta externa .jar con timeout
    timeout 15s java -jar "$JAR_FILE" createUnsignedRawEthereumTx "$PUB_KEY_COMPRESSED" "$DEST_ADDRESS" "$AMOUNT" 2>&1 | tee /tmp/jar_output.log
    
    # Verificar la salida del comando jar y capturar el hash correcto
    HASH_TO_SIGN=$(grep 'Hash to sign' /tmp/jar_output.log | awk -F': ' '{print $3}')
    
    if [ -z "$HASH_TO_SIGN" ]; then
        echo "Error: No se pudo generar el hash a firmar."
        exit 1
    fi
    
    # Guarda el hash en el archivo temporal
    echo "$HASH_TO_SIGN" > "$RAW_TX_FILE"
else
    # Lee el hash del archivo temporal
    HASH_TO_SIGN=$(cat "$RAW_TX_FILE")
fi

# Extraer la transacción sin firmar en hexadecimal (txInHex)
TX_IN_HEX=$(grep -A 1 'You can decode the transaction in https://rawtxdecode.in/' /tmp/jar_output.log | tail -n 1)

echo "Hash generado: $HASH_TO_SIGN"
echo "Transacción sin firmar (txInHex): $TX_IN_HEX"

echo "----------------PASO 9--------------------"
echo "Firmar la transacción y guardar la salida en un archivo"
# Firma la transacción y guarda la salida en un archivo
./tss sign --home ./${DIR_PARTY} --vault_name $VAULT_NAME --password $PASSWORD --channel_password $PASSWORD --channel_id $(cat ../"$CHANNEL_FILE") --message "0x$HASH_TO_SIGN" > "$SIGN_OUTPUT_FILE" 2>&1

echo "----------------PASO 10--------------------"
echo "Extraer la firma de la transacción desde el archivo de salida"
# Extrae la firma de la transacción desde el archivo de salida
SIGNATURE=$(grep -oP 'received signature: \K[0-9a-fA-F]+' "$SIGN_OUTPUT_FILE")

echo "Transacción firmada: $SIGNATURE"
echo "Guardando la firma en $SIGNED_TX_FILE"
# Guarda la firma en el archivo SIGNED_TX_FILE
echo "$SIGNATURE" > "$SIGNED_TX_FILE"

echo "----------------PASO 11--------------------"
echo "Agregar la firma a la transacción sin firmar para obtener la transacción final"
# Agregar la firma a la transacción sin firmar
FINAL_TX=$(timeout 10s java -jar "$JAR_FILE" addSignToUnsignedRawEthereumTx --pubKeyInHex "$PUB_KEY_COMPRESSED" --txInHex "$TX_IN_HEX" --signatureInHex "$SIGNATURE" --messageHashInHex "$HASH_TO_SIGN" 2>&1 | tee /tmp/jar_output_addsign.log)

# Extraer la transacción final del log
FINAL_TX_HEX=$(grep -oP '^0x[0-9a-fA-F]+' /tmp/jar_output_addsign.log)

# Verificar y guardar la transacción final
if [ -z "$FINAL_TX_HEX" ]; then
    echo "Error: No se pudo generar la transacción final."
    exit 1
fi

echo "Transacción final generada: $FINAL_TX_HEX"
echo "$FINAL_TX_HEX" > "$FINAL_TX_FILE"

echo "----------------PASO 12--------------------"
echo "Transmitir la transacción final usando ethRpcSendRawTx"
# Transmitir la transacción final
TX_ID=$(java -jar "$JAR_FILE" ethRpcSendRawTx --txInHex "$FINAL_TX_HEX")

# Verificar y mostrar el ID de la transacción
if [ -z "$TX_ID" ]; then
    echo "Error: No se pudo transmitir la transacción."
    exit 1
fi

echo "Transacción transmitida exitosamente. TX ID: $TX_ID"

echo "Proceso completado."
