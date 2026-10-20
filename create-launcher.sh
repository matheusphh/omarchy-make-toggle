#!/usr/bin/env bash
# Creates a launcher (.desktop file) in ~/.local/share/applications
# The icon can be: a local path, a theme icon name, or a URL (http/htubik%27s_cube.svg.png?utm_source=pt.wikipedia.org&utm_campaign=index&utm_content=thumbnail


clear
echo "
                 ▄▄▄
 ▄█████▄    ▄███████████▄    ▄███████   ▄███████   ▄███████   ▄█   █▄    ▄█   █▄
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   █▀   ███   ███  ███   ███
███   ███  ███   ███   ███ ▄███▄▄▄███ ▄███▄▄▄██▀  ███       ▄███▄▄▄███▄ ███▄▄▄███
███   ███  ███   ███   ███ ▀███▀▀▀███ ▀███▀▀▀▀    ███      ▀▀███▀▀▀███  ▀▀▀▀▀▀███
███   ███  ███   ███   ███  ███   ███ ██████████  ███   █▄   ███   ███  ▄██   ███
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
 ▀█████▀    ▀█   ███   █▀   ███   █▀   ███   ███  ███████▀   ███   █▀    ▀█████▀
                                       ███   █▀
"
echo "Let's create a app you can start with the app launcher.
"

DEST_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$DEST_DIR"

# Downloads an icon from the web into ~/.local/share/icons and prints the final path.
# Messages go to stderr so they don't pollute the returned value.
download_icon() {
    local url="$1" base="$2" tmp mime ext

    mkdir -p "$ICON_DIR"
    tmp="$(mktemp)"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --proto '=http,https' --max-time 30 -o "$tmp" -- "$url" || { rm -f "$tmp"; return 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 30 -O "$tmp" -- "$url" || { rm -f "$tmp"; return 1; }
    else
        echo "Error: please install curl or wget to download icons." >&2
        rm -f "$tmp"
        return 1
    fi

    # Detects the real file type (doesn't trust the URL extension)
    if command -v file >/dev/null 2>&1; then
        mime="$(file -b --mime-type "$tmp")"
    fi
    if [[ "$mime" != image/* ]] && grep -qi '<svg' "$tmp" 2>/dev/null; then
        mime="image/svg+xml"
    fi

    case "$mime" in
        image/png)                             ext="png"  ;;
        image/svg+xml)                         ext="svg"  ;;
        image/jpeg)                            ext="jpg"  ;;
        image/webp)                            ext="webp" ;;
        image/x-icon|image/vnd.microsoft.icon) ext="ico"  ;;
        *)
            echo "Error: the downloaded file is not a supported image (${mime:-unknown type})." >&2
            rm -f "$tmp"
            return 1
            ;;
    esac

    local dest="$ICON_DIR/$base.$ext"
    mv "$tmp" "$dest"
    chmod 644 "$dest"
    echo "$dest"
}

read -rp "Application name> " name
read -rp "Path to the executable> " exec_path
read -rp "Icon (path, http(s) URL, or theme icon name)> " icon

# Expands ~ in case the user typed it
exec_path="${exec_path/#\~/$HOME}"
icon="${icon/#\~/$HOME}"

# Basic validation
if [[ -z "$name" || -z "$exec_path" ]]; then
    echo "Error: application name and executable path are required." >&2
    exit 1
fi

if [[ ! -e "$exec_path" ]]; then
    echo "Warning: '$exec_path' does not exist (the launcher will be created anyway)."
fi

file_base="${name// /-}"

# Icon from the web: download it and use the local path
if [[ "$icon" =~ ^https?:// ]]; then
    echo "Downloading icon..."
    if downloaded_icon="$(download_icon "$icon" "$file_base")"; then
        icon="$downloaded_icon"
        echo "Icon saved to: $icon"
    else
        echo "Warning: could not download the icon. Using a generic icon." >&2
        icon="application-x-executable"
    fi
elif [[ "$icon" == /* && ! -e "$icon" ]]; then
    echo "Warning: the icon file '$icon' does not exist."
fi

# Paths with spaces need quotes in the Exec field
if [[ "$exec_path" == *" "* ]]; then
    exec_value="\"$exec_path\""
else
    exec_value="$exec_path"
fi

desktop_file="$DEST_DIR/$file_base.desktop"

if [[ -e "$desktop_file" ]]; then
    read -rp "'$desktop_file' already exists. Overwrite? [y/N] " answer
    [[ "$answer" =~ ^[yY]$ ]] || { echo "Cancelled."; exit 0; }
fi

cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Name=$name
Exec=$exec_value
Terminal=false
Type=Application
Icon=$icon
StartupNotify=true
EOF

chmod +x "$desktop_file"

# Refreshes the menu cache, if the command is available
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DEST_DIR" 2>/dev/null

echo "Launcher created at: $desktop_file"
