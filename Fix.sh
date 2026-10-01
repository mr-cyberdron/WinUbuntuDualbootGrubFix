#!/usr/bin/env bash
set -euo pipefail

# Если запустили не от root — перезапускаем через sudo
if [ "$EUID" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

GRUB_CFG="/etc/default/grub"

echo "=== Installing os-prober ==="

if ! command -v os-prober >/dev/null 2>&1; then
    apt-get update
    apt-get install -y os-prober
fi

# Проверяем, видит ли Linux Windows
echo "=== Searching for Windows ==="

if ! os-prober | grep -qi "Windows"; then
    echo "ERROR: Windows was not found."
    exit 1
fi

# Резервная копия конфигурации GRUB
cp -a "$GRUB_CFG" "${GRUB_CFG}.backup"

set_grub_option() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$GRUB_CFG"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$GRUB_CFG"
    else
        echo "${key}=${value}" >> "$GRUB_CFG"
    fi
}

echo "=== Configuring GRUB ==="

set_grub_option "GRUB_DISABLE_OS_PROBER" "false"
set_grub_option "GRUB_TIMEOUT_STYLE" "menu"
set_grub_option "GRUB_TIMEOUT" "5"
set_grub_option "GRUB_DEFAULT" "saved"

# Создаём актуальное меню GRUB
update-grub

# Находим точное название пункта Windows
WINDOWS_ENTRY="$(
    grep "^menuentry 'Windows" /boot/grub/grub.cfg \
    | head -n 1 \
    | cut -d"'" -f2 \
    || true
)"

if [ -z "$WINDOWS_ENTRY" ]; then
    echo "ERROR: Windows entry was not found in GRUB."
    exit 1
fi

echo "Found Windows entry:"
echo "$WINDOWS_ENTRY"

# Делаем Windows загрузкой по умолчанию
grub-set-default "$WINDOWS_ENTRY"

echo
echo "===================================="
echo "GRUB configured successfully."
echo "Default OS: $WINDOWS_ENTRY"
echo "Menu timeout: 5 seconds"
echo "===================================="
echo
echo "Reboot with:"
echo "sudo reboot"