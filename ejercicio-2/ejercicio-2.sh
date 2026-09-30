#!/bin/bash

ARCH_PRODUCTOS="productos.tsv"
ARCH_USUARIOS="usuarios.tsv"

# Crear archivos si no existen
[ ! -f "$ARCH_PRODUCTOS" ] && touch "$ARCH_PRODUCTOS"
[ ! -f "$ARCH_USUARIOS" ] && touch "$ARCH_USUARIOS"

# ==========================================
# FUNCIONES DE AUTENTICACIÓN
# ==========================================

cifrar_clave() {
    local pass="$1"
    local hash=$(echo -n "$pass" | sha256sum | cut -d' ' -f1)
    echo "$hash"
}

registrar_usuario() {
    echo ""
    echo "=== REGISTRAR USUARIO ==="
    read -p "Ingrese nombre de usuario: " user
    
    if [ -z "$user" ]; then
        echo "El usuario no puede estar vacío."
        return
    fi

    while IFS=$'\t' read -r u p; do
        if [ "$u" == "$user" ]; then
            echo "Error: El usuario '$user' ya existe."
            return
        fi
    done < "$ARCH_USUARIOS"

    read -s -p "Ingrese contraseña: " pass
    echo ""
    
    if [ -z "$pass" ]; then
        echo "La contraseña no puede estar vacía."
        return
    fi

    local pass_hash=$(cifrar_clave "$pass")
    echo -e "${user}\t${pass_hash}" >> "$ARCH_USUARIOS"
    echo "¡Usuario registrado con éxito!"
}

iniciar_sesion() {
    echo ""
    echo "=== INICIAR SESIÓN ==="
    read -p "Usuario: " user
    read -s -p "Contraseña: " pass
    echo ""

    local pass_hash=$(cifrar_clave "$pass")
    local autenticado=0

    while IFS=$'\t' read -r u p; do
        if [ "$u" == "$user" ] && [ "$p" == "$pass_hash" ]; then
            autenticado=1
            break
        fi
    done < "$ARCH_USUARIOS"

    if [ $autenticado -eq 1 ]; then
        echo "Acceso concedido. ¡Bienvenido $user!"
        return 0
    else
        echo "Error: Usuario o contraseña incorrectos."
        return 1
    fi
}

# ==========================================
# FUNCIONES DE PRODUCTOS
# ==========================================

alta_producto() {
    echo ""
    echo "=== ALTA DE PRODUCTO ==="
    read -p "Ingrese ID: " id
    read -p "Ingrese Nombre: " nombre
    read -p "Ingrese Precio: " precio

    if [ -z "$id" ] || [ -z "$nombre" ] || [ -z "$precio" ]; then
        echo "Error: Todos los campos son obligatorios."
        return
    fi

    local existe=0
    while IFS=$'\t' read -r pid pnom pprec; do
        if [ "$pid" == "$id" ]; then
            echo "Error: Ya existe un producto con el ID '$id'."
            existe=1
            break
        elif [ "$pnom" == "$nombre" ]; then
            echo "Error: Ya existe un producto con el nombre '$nombre'."
            existe=1
            break
        fi
    done < "$ARCH_PRODUCTOS"

    if [ $existe -eq 0 ]; then
        echo -e "${id}\t${nombre}\t${precio}" >> "$ARCH_PRODUCTOS"
        echo "Producto agregado correctamente."
    fi
}

baja_producto() {
    echo ""
    echo "=== BAJA DE PRODUCTO ==="
    read -p "Ingrese el ID del producto a eliminar: " id

    if ! grep -q "^${id}\t" "$ARCH_PRODUCTOS"; then
        echo "Error: El producto con ID '$id' no existe."
        return
    fi

    grep -v "^${id}\t" "$ARCH_PRODUCTOS" > productos.tmp && mv productos.tmp "$ARCH_PRODUCTOS"
    echo "Producto eliminado correctamente."
}

editar_producto() {
    echo ""
    echo "=== EDITAR PRODUCTO ==="
    read -p "Ingrese el ID del producto a editar: " id

    if ! grep -q "^${id}\t" "$ARCH_PRODUCTOS"; then
        echo "Error: El producto con ID '$id' no existe."
        return
    fi

    read -p "Ingrese nuevo Nombre: " nuevo_nombre
    read -p "Ingrese nuevo Precio: " nuevo_precio

    if [ -z "$nuevo_nombre" ] || [ -z "$nuevo_precio" ]; then
        echo "Error: Los campos no pueden estar vacíos."
        return
    fi

    grep -v "^${id}\t" "$ARCH_PRODUCTOS" > productos.tmp
    echo -e "${id}\t${nuevo_nombre}\t${nuevo_precio}" >> productos.tmp
    mv productos.tmp "$ARCH_PRODUCTOS"
    echo "Producto actualizado correctamente."
}

mostrar_inventario() {
    echo ""
    echo "=== INVENTARIO DE PRODUCTOS ==="
    if [ ! -s "$ARCH_PRODUCTOS" ]; then
        echo "El inventario está vacío."
        return
    fi

    printf "%-10s %-20s %-10s\n" "ID" "NOMBRE" "PRECIO"
    echo "----------------------------------------"
    while IFS=$'\t' read -r id nombre precio; do
        printf "%-10s %-20s %-10s\n" "$id" "$nombre" "$precio"
    done < "$ARCH_PRODUCTOS"
}

generar_reporte_html() {
    local arch_html="productos.html"

    cat <<EOF > "$arch_html"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Reporte de Productos</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 50%; margin-top: 10px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Reporte de Inventario de Productos</h1>
    <table>
        <thead>
            <tr>
                <th>ID</th>
                <th>Nombre</th>
                <th>Precio</th>
            </tr>
        </thead>
        <tbody>
EOF

    while IFS=$'\t' read -r id nombre precio; do
        if [ -n "$id" ]; then
            echo "            <tr><td>$id</td><td>$nombre</td><td>$precio</td></tr>" >> "$arch_html"
        fi
    done < "$ARCH_PRODUCTOS"

    cat <<EOF >> "$arch_html"
        </tbody>
    </table>
</body>
</html>
EOF

    echo "Reporte 'productos.html' generado exitosamente."
}

# ==========================================
# MENÚ PRINCIPAL Y AUTENTICACIÓN
# ==========================================

menu_principal() {
    while true; do
        echo ""
        echo "=== MENÚ PRINCIPAL ==="
        echo "1. Alta producto"
        echo "2. Baja producto"
        echo "3. Editar producto"
        echo "4. Mostrar inventario"
        echo "5. Generar reporte HTML"
        echo "6. Salir"
        read -p "Opción: " opc

        case $opc in
            1) alta_producto ;;
            2) baja_producto ;;
            3) editar_producto ;;
            4) mostrar_inventario ;;
            5) generar_reporte_html ;;
            6) echo "Saliendo del programa..."; break ;;
            *) echo "Opción inválida." ;;
        esac
    done
}

while true; do
    echo ""
    echo "=========================================="
    echo "       SISTEMA DE GESTIÓN DE PRODUCTOS    "
    echo "=========================================="
    echo "1. Iniciar sesión"
    echo "2. Registrar usuario"
    echo "3. Salir"
    read -p "Seleccione una opción: " opcion

    case $opcion in
        1)
            if iniciar_sesion; then
                menu_principal
            fi
            ;;
        2)
            registrar_usuario
            ;;
        3)
            echo "¡Hasta luego!"
            exit 0
            ;;
        *)
            echo "Opción no válida."
            ;;
    esac
done

