#!/bin/bash

# -------------------------------------------------------------------
# Rutas y Variables Globales
# -------------------------------------------------------------------
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$DIR/data.sq3"
LOG_FILE="$DIR/system.log"
ERR_FILE="$DIR/error.log"
HTML_FILE="$DIR/productos.html"

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
        sqlite3 "$DB_FILE" <<EOF 2>> "$ERR_FILE"
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
EOF
        log_action "0" "SYSTEM" "Base de datos creada e inicializada."
    fi
}

# -------------------------------------------------------------------
# Módulo de Autenticación de Usuarios
# -------------------------------------------------------------------
autenticar_usuario() {
    read -p "Ingrese usuario: " usuario
    read -s -p "Ingrese contraseña: " password
    echo ""

    # Calcular hash SHA-256 de la contraseña
    pass_hash=$(echo -n "$password" | sha256sum | awk '{print $1}')

    # Consultar si el usuario existe
    user_data=$(sqlite3 "$DB_FILE" "SELECT id, password_hash FROM usuarios WHERE username='$usuario';" 2>> "$ERR_FILE")

    if [ -z "$user_data" ]; then
        # Usuario no existe -> Registrarlo
        sqlite3 "$DB_FILE" "INSERT INTO usuarios (username, password_hash) VALUES ('$usuario', '$pass_hash');" 2>> "$ERR_FILE"
        CURRENT_USER_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM usuarios WHERE username='$usuario';" 2>> "$ERR_FILE")
        CURRENT_USERNAME="$usuario"
        
        echo "Usuario registrado exitosamente."
        log_action "$CURRENT_USER_ID" "$CURRENT_USERNAME" "Registro de nuevo usuario"
    else
        # Usuario existe -> Validar hash
        CURRENT_USER_ID=$(echo "$user_data" | cut -d'|' -f1)
        stored_hash=$(echo "$user_data" | cut -d'|' -f2)

        if [ "$pass_hash" == "$stored_hash" ]; then
            CURRENT_USERNAME="$usuario"
            echo "Autenticación exitosa."
            log_action "$CURRENT_USER_ID" "$CURRENT_USERNAME" "Inicio de sesion exitoso"
        else
            echo "Contraseña incorrecta."
            log_action "$CURRENT_USER_ID" "$usuario" "Fallo de autenticacion (contraseña incorrecta)"
            exit 1
        fi
    fi
}

# -------------------------------------------------------------------
# Módulo de Gestión de Productos
# -------------------------------------------------------------------
registrar_producto() {
    read -p "Ingrese nombre del producto: " producto
    read -p "Ingrese valor del producto: " valor

    # Inserción SQL
    sqlite3 "$DB_FILE" "INSERT INTO productos (nombre, precio) VALUES ('$producto', $valor);" 2>> "$ERR_FILE"
    echo "Producto guardado."
    
    log_action "$CURRENT_USER_ID" "$CURRENT_USERNAME" "Carga de producto: $producto ($valor)"
}

# -------------------------------------------------------------------
# Generación del Reporte HTML a partir de SQL
# -------------------------------------------------------------------
generar_html() {
    cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Lista de Productos</title>
    <style>
        table { border-collapse: collapse; width: 50%; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h2>Productos Registrados</h2>
    <table>
        <tr>
            <th>ID</th>
            <th>Producto</th>
            <th>Precio</th>
        </tr>
EOF

    # Consultar datos en SQLite3 y formatear en filas HTML
    sqlite3 -separator ' ' "$DB_FILE" "SELECT id, nombre, precio FROM productos;" 2>> "$ERR_FILE" | while read -r id prod val; do
        if [ -n "$prod" ]; then
            echo "        <tr><td>$id</td><td>$prod</td><td>$val</td></tr>" >> "$HTML_FILE"
        fi
    done

    cat <<EOF >> "$HTML_FILE"
    </table>
</body>
</html>
EOF

    log_action "$CURRENT_USER_ID" "$CURRENT_USERNAME" "Generacion de reporte HTML"
}

# -------------------------------------------------------------------
# Flujo Principal
# -------------------------------------------------------------------
main() {
    init_db
    autenticar_usuario
    registrar_producto
    generar_html
}

main
