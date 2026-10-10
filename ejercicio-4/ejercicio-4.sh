#!/bin/bash

# -------------------------------------------------------------------
# Rutas y Variables Globales
# -------------------------------------------------------------------
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$DIR/data.sq3"
LOG_FILE="$DIR/system.log"
ERR_FILE="$DIR/error.log"
HTML_FILE="$DIR/productos.html"

CURRENT_USER_ID=""
CURRENT_USERNAME=""

# -------------------------------------------------------------------
# Funciones de Auditoría y Logs
# -------------------------------------------------------------------
log_action() {
    local user_id="$1"
    local username="$2"
    local action="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp}\t${user_id}\t${username}\t${action}" >> "$LOG_FILE"
}

# -------------------------------------------------------------------
# Inicialización de la Base de Datos (SQLite3)
# -------------------------------------------------------------------
init_db() {
    if [ ! -f "$DB_FILE" ]; then
        sqlite3 "$DB_FILE" <<EOF_SQL 2>> "$ERR_FILE"
CREATE TABLE IF NOT EXISTS usuarios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS productos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    precio REAL NOT NULL
);
EOF_SQL
        log_action "0" "SYSTEM" "Base de datos TUI creada e inicializada."
    fi
}

# -------------------------------------------------------------------
# Módulo de Autenticación con Whiptail (TUI)
# -------------------------------------------------------------------
autenticar_usuario() {
    usuario=$(whiptail --title "Sistemas Operativos - TUI" --inputbox "Ingrese su nombre de usuario:" 10 50 3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ] || [ -z "$usuario" ]; then
        whiptail --title "Cancelado" --msgbox "Operación cancelada por el usuario." 8 45
        exit 0
    fi

    password=$(whiptail --title "Sistemas Operativos - TUI" --passwordbox "Ingrese su contraseña para [$usuario]:" 10 50 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        whiptail --title "Cancelado" --msgbox "Operación cancelada." 8 45
        exit 0
    fi

    pass_hash=$(echo -n "$password" | sha256sum | awk '{print $1}')
    user_data=$(sqlite3 "$DB_FILE" "SELECT id, password_hash FROM usuarios WHERE username='$usuario';" 2>> "$ERR_FILE")

    if [ -z "$user_data" ]; then
        sqlite3 "$DB_FILE" "INSERT INTO usuarios (username, password_hash) VALUES ('$usuario', '$pass_hash');" 2>> "$ERR_FILE"
        CURRENT_USER_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM usuarios WHERE username='$usuario';" 2>> "$ERR_FILE")
        CURRENT_USERNAME="$usuario"
        
        whiptail --title "Registro Exitoso" --msgbox "Usuario '$usuario' registrado correctamente en el sistema." 8 50
        log_action "$CURRENT_USER_ID" "$CURRENT_USERNAME" "Registro TUI de nuevo usuario"
    else
        CURRENT_USER_ID=$(echo "$user_data" | cut -d'|' -f1)
        stored_hash=$(echo "$user_data" | cut -d'|' -f2)

        if [ "$pass_hash" == "$stored_hash" ]; then
            CURRENT_USERNAME="$usuario"
            whiptail --title "Bienvenido" --msgbox "Autenticación exitosa. ¡Hola, $usuario!" 8 45
            log_action "$CURRENT_USER_ID" "$CURRENT_USERNAME" "Inicio de sesion TUI exitoso"
        else
            whiptail --title "Error" --msgbox "Contraseña incorrecta. Acceso denegado." 8 45
            log_action "$CURRENT_USER_ID" "$usuario" "Fallo de autenticacion TUI (password incorrecto)"
            exit 1
        fi
    fi
}

# -------------------------------------------------------------------
# Módulo de Gestión de Productos con Inputs Individuales
# -------------------------------------------------------------------
registrar_producto() {
    producto=$(whiptail --title "Gestión de Productos" --inputbox "Ingrese el nombre del producto:" 10 50 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$producto" ]; then
        return
    fi

    valor=$(whiptail --title "Gestión de Productos" --inputbox "Ingrese el precio para [$producto]:" 10 50 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$valor" ]; then
        return
    fi

    if ! [[ "$valor" =~ ^[0-9]+([.,][0-9]+)?$ ]]; then
        whiptail --title "Error" --msgbox "El precio debe ser un valor numérico válido." 8 45
        return
    fi

    valor=$(echo "$valor" | tr ',' '.')

    sqlite3 "$DB_FILE" "INSERT INTO productos (nombre, precio) VALUES ('$producto', $valor);" 2>> "$ERR_FILE"
    
    whiptail --title "Éxito" --msgbox "Producto '$producto' guardado correctamente." 8 45
    log_action "$CURRENT_USER_ID" "$CURRENT_USERNAME" "Carga TUI de producto: $producto ($valor)"
}

# -------------------------------------------------------------------
# Visualización de Registros en Ventana de Texto (TextBox)
# -------------------------------------------------------------------
ver_productos() {
    temp_file=$(mktemp)
    echo "ID | NOMBRE | PRECIO" > "$temp_file"
    echo "----------------------------------------" >> "$temp_file"
    sqlite3 -separator ' | ' "$DB_FILE" "SELECT id, nombre, precio FROM productos;" >> "$temp_file"
    
    whiptail --title "Listado de Productos Registrados" --textbox "$temp_file" 20 60
    rm -f "$temp_file"
}

ver_logs() {
    if [ -f "$LOG_FILE" ]; then
        whiptail --title "Registro de Auditoría (system.log)" --textbox "$LOG_FILE" 20 75
    else
        whiptail --title "Aviso" --msgbox "Aún no hay registros en el archivo system.log." 8 50
    fi
}

# -------------------------------------------------------------------
# Generación del Reporte HTML
# -------------------------------------------------------------------
generar_html() {
    cat <<EOF_HTML > "$HTML_FILE"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Lista de Productos</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f9f9f9; }
        h2 { color: #333; }
        table { border-collapse: collapse; width: 60%; background: #fff; box-shadow: 0px 0px 10px rgba(0,0,0,0.1); }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background-color: #007ACC; color: white; }
    </style>
</head>
<body>
    <h2>Reporte de Productos Registrados (TUI)</h2>
    <table>
        <tr>
            <th>ID</th>
            <th>Producto</th>
            <th>Precio</th>
        </tr>
EOF_HTML

    sqlite3 "$DB_FILE" "SELECT id, nombre, precio FROM productos;" 2>> "$ERR_FILE" | while IFS='|' read -r id prod val; do
        if [ -n "$prod" ]; then
            echo "        <tr><td>$id</td><td>$prod</td><td>$val</td></tr>" >> "$HTML_FILE"
        fi
    done

    cat <<EOF_HTML_END >> "$HTML_FILE"
    </table>
</body>
</html>
EOF_HTML_END

    whiptail --title "Reporte HTML" --msgbox "Reporte web generado con éxito en:\n$HTML_FILE" 9 50
    log_action "$CURRENT_USER_ID" "$CURRENT_USERNAME" "Generacion TUI de reporte HTML"
}

# -------------------------------------------------------------------
# Menú Principal Interactivo (TUI Loop)
# -------------------------------------------------------------------
main() {
    init_db
    autenticar_usuario

    while true; do
        OPCION=$(whiptail --title "Menú Principal - Ejercicio 4 (TUI)" --menu "Usuario activo: $CURRENT_USERNAME\nElija una opción:" 16 60 5 \
        "1" "Registrar nuevo producto" \
        "2" "Ver lista de productos" \
        "3" "Ver archivo de auditoría (Logs)" \
        "4" "Generar reporte HTML" \
        "5" "Salir del sistema" 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            break
        fi

        case $OPCION in
            1) registrar_producto ;;
            2) ver_productos ;;
            3) ver_logs ;;
            4) generar_html ;;
            5) 
               whiptail --title "Hasta luego" --msgbox "Saliendo del sistema TUI." 8 45
               break 
               ;;
        esac
    done
}

main
