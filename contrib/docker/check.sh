

#!/bin/sh

env | while IFS='=' read -r name value; do
    case "$name" in
        *_DIR)
            printf 'checking %s = %s ...\n' "$name" "$value"
            if [ ! -d "$value" ]; then
                printf 'missing directory: %s = %s\n' "$name" "$value" >&2
                exit 1
            fi
            ;;
    esac
done || exit 1

echo "OK"
exit 0
