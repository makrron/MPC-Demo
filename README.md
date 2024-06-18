# Demo MPC

Este proyecto incluye dos scripts `keygen.sh` y `sign.sh` para la generación de claves y la firma de transacciones respectivamente, haciendo uso de las herramientas [TSS](https://github.com/ivansjg/tss) y [Ethereum-tool](https://github.com/ivansjg/ethereum-tool)

## Requerimientos del Sistema

Para ejecutar estos scripts, se necesitan los siguientes requerimientos:

1. **Sistema Operativo**: Linux (preferiblemente Ubuntu/Debian).
2. **Dependencias**:
   - `go` (Instalado en `/usr/local/go/bin/go`)
   - `git`
   - `java`
   - Librerías necesarias para la compilación del repositorio `tss`.
3. **Permisos**: Asegúrate de que los scripts tienen permisos de ejecución.

## Instalación de Dependencias

Puedes instalar las dependencias necesarias ejecutando los siguientes comandos:

```sh
sudo apt-get update
sudo apt-get install -y golang git default-jre
```

# Uso
## keygen.sh

Este script genera claves utilizando una implementación de [TSS](https://github.com/ivansjg/tss) (Threshold Signature Scheme)

Sintaxis
```sh
./keygen.sh <nombre> <contraseña> <puerto_p2p> <directorio_home>
```

Ejemplo
```sh
./keygen.sh "test1" "123456789" 54964 ".test1"         
```
### Descripción de los Argumentos
    <nombre>: Nombre del moniker.
    <contraseña>: Contraseña para la party.
    <puerto_p2p>: Puerto P2P.
    <directorio_home>: Directorio home donde se almacenarán los archivos generados.

### Pasos del Script keygen.sh

    Verificar los argumentos proporcionados.
    Asignar variables a partir de los argumentos.
    Verificar que go está instalado en la ruta especificada.
    Agregar go al PATH temporalmente para esta sesión.
    Clonar y construir el binario de TSS si no está ya.
    Inicializar la party MPC estableciendo el threshold a 3 (1+t)

    Se deberá lanzar el script dos veces más para que se inicie correctamente el intercambio de informacion, ya que el threshold esta establecido a 3.



## sign.sh

Este script firma una transacción utilizando una clave generada previamente. Serán necesarias dos parties para realizar la firma. En el proceso de firma se utiliza la herramienta [Ethereum-tool](https://github.com/ivansjg/ethereum-tool)

Sintaxis
```sh
./sign.sh <nombre> <contraseña> <directorio_home> <direccion> <cantidad>
```

Ejemplo
```sh
./sign.sh "test1" "123456789" ".test1" 0x0851056A45aC3083f69613934A35876ac54715cD 1        
```

Descripción de los Argumentos

    <nombre>: Nombre del moniker.
    <contraseña>: Contraseña para la party.
    <directorio_home>: Directorio home donde se almacenaron las claves.
    <direccion>: Direccion a la que se va a enviar la cantidad especificada.
    <cantidad>: Cantidad a enviar (en dolares)

Pasos del Script sign.sh

    Verificar los argumentos proporcionados.
    Asignar variables a partir de los argumentos.
    Comprobar la existencia de archivos y directorios necesarios.
    Leer y preparar la transacción a firmar.
    Firmar la transacción y guardar la salida en un archivo.
    Extraer la firma de la transacción desde el archivo de salida.
    Agregar la firma a la transacción sin firmar para obtener la transacción final.
    Transmitir la transacción final usando ethRpcSendRawTx.
