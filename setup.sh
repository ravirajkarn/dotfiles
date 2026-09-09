#!/bin/bash
set -e

function apt_install() {
    CMD_NAME="$1"
    PKG_NAME="${2:-$1}"

    if [ -z "$CMD_NAME" ]; then
        echo "Error: No package name provided."
        return 1
    fi

    if ! command -v $CMD_NAME &>/dev/null; then
        echo "Installing $PKG_NAME..."
        sudo apt-get install -y "$PKG_NAME"
    else
        echo "$PKG_NAME is already installed."
    fi
}

function pipx_install() {
    APP="$1"

    if [ -z "$APP" ]; then
        echo "Error: No package name provided."
        return 1
    fi

    if ! command -v $APP &>/dev/null; then
        echo "Installing $APP..."
        pipx install "$APP"
    else
        echo "$APP is already installed."
    fi
}

function setup_syncthing() {
    echo "syncthing: "

    apt_install syncthing
    
    if ! systemctl is-active --quiet syncthing@$USER.service; then
        echo -e "\nStarting and enabling syncthing service..."
        sudo systemctl enable --now syncthing@$USER.service
    else
        echo -e "\nSyncthing service is already running."
    fi
    echo
}

function setup_conan() {
    echo "conan: "
    _CONAN="$HOME/.conan2/profiles"
    
    pipx_install conan

    mkdir -p "$HOME/.conan2"

    if [ -e "$_CONAN" ] || [ -L "$_CONAN" ] ; then
        echo -e "\nremoving $_CONAN"
        rm -rf "$_CONAN"
    else
        echo -e "\nnot found $_CONAN"
    fi

    echo -e "\ncreating symbolic link: $_CONAN "
    ln -s "$PWD/conan" "$_CONAN"
    echo ""
}


function setup_grub() {
    echo "GRUB: "
    _GRUB="/usr/share/grub/themes/Elegant-forest-window-right-dark"
    _SOURCE="$PWD/Elegant-forest-window-right-dark"

    if [ -e "$_GRUB" ] || [ -L "$_GRUB" ]; then
        echo "removing $_GRUB"
        sudo rm -rf "$_GRUB"
    else
        echo "not found $_GRUB"
    fi

    echo "creating symbolic link: $_GRUB "

    sudo ln -s "$_SOURCE" "$_GRUB"
    sudo update-grub

    echo
}



function setup_kitty() {
    echo "Kitty: "
    KITTY="$HOME/.config/kitty"

    apt_install kitty

    if [ -e "$KITTY" ] || [ -L "$KITTY" ]; then
        echo "removing $KITTY" 
        rm -rf "$KITTY"
    else
        echo "not found $KITTY"
    fi

    echo "creating symbolic link: $KITTY " 
    ln -s "$PWD/kitty" "$KITTY"

    echo
}

function setup_fzf() {
    echo "fzf: "
    apt_install fzf
    echo
}

function setup_lazygit() {
    echo "lazygit: "
    apt_install lazygit
    echo
}

function setup_fd_find() {
    echo "fd-find: "
    apt_install fd fd-find
    echo
}

function setup_ripgrep() {
    echo "ripgrep: "
    apt_install rg ripgrep
    echo
}

function setup_unzip() {
    echo "unzip: "
    apt_install unzip
    echo
}

function setup_lua() {
    echo "lua: "
    sudo apt-get install -y lua5.4 liblua5.4-dev luajit libluajit-5.1-dev luarocks
    echo
}

function setup_neovim() {
    echo "Neo Vim: "
    _NVIM="$HOME/.config/nvim"
    
    # Dependency 
    setup_fzf
    setup_lazygit
    setup_fd_find
    setup_ripgrep
    setup_unzip
    setup_lua
    apt_install gcc build-essential

    apt_install nvim neovim 

    if [ -e "$_NVIM" ] || [ -L "$_NVIM" ]; then
        echo -e "\nremoving $_NVIM"
        rm -rf "$_NVIM"
    else
        echo -e "\nnot found $_NVIM"
    fi

    echo -e "\ncreating symbolic link: $_NVIM "
    ln -s "$PWD/nvim" "$_NVIM"
    echo
}


# _SILENT=$PWD/silent/install.sh
# if [ ! command -v sddm ] &>/dev/null; then
#     echo "Installing sddm"
#     sudo apt-get install -y sddm
# fi
# $_SILENT
# echo

function setup_tlp() {
    echo "TLP: "
    _TLP_DIR="/etc/tlp.d"
    _MY_CONF="$PWD/tlp"

    apt_install tlp
    
    sudo mkdir -p "$_TLP_DIR"

    echo -e "\ncreating symbolic link in: $_TLP_DIR"
    for file in "$_MY_CONF"/*; do 
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            target="$_TLP_DIR/$filename"

            if [ -e "$target" ] && [ ! -L "$target" ]; then
                echo " -> Backing up existing regular file: $filename"
                sudo mv "$target" "${target}.bak"
            fi
            
            sudo ln -sf "$file" "$target"
            echo " -> Linked $filename"
        fi
    done

    sudo systemctl enable --now tlp.service
    echo
}

function setup_tmux() {
    echo "tmux: "
    _TMUX_DIR="$HOME/.config/tmux"
    _MY_CONF="$PWD/tlp"
    
    apt_install tmux
    apt_install acpi

    mkdir -p "$HOME/.config"
    
    if [ -e "$_TMUX_DIR" ]; then
        echo -e "\nremoving $_TMUX_DIR" 
        rm -rf "$_TMUX_DIR"
    else
        echo -e "\nnot found $_TMUX_DIR"
    fi

    echo -e "\ncreating symbolic link: $_TMUX_DIR"
    ln -s "$PWD/tmux" "$_TMUX_DIR"

    if tmux ls &> /dev/null; then 
        echo -e "\nTmux session detected. Applying new configuration..."
        tmux source-file "$_TMUX_DIR/tmux.conf"
    fi
    
    echo
}

function setup_fonts() {
    # --- Define Colors ---
    local RESET='\e[0m'
    local BOLD='\e[1m'
    local BLUE='\e[34m'
    local CYAN='\e[36m'
    local GREEN='\e[32m'
    local YELLOW='\e[33m'
    local RED='\e[31m'

    echo -e "${BOLD}${BLUE}:: Fonts Setup${RESET}"

    _FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$_FONT_DIR"

    URLS=(
        "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
        "https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip"
        "https://github.com/i-tu/Hasklig/releases/download/v1.2/Hasklig-1.2.zip"
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Monoid.zip"
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/CascadiaCode.zip"
        "https://github.com/be5invis/Iosevka/releases/download/v34.8.1/PkgTTC-SGr-Iosevka-34.8.1.zip"
        "https://github.com/be5invis/Iosevka/releases/download/v34.8.1/PkgTTC-SGr-IosevkaTerm-34.8.1.zip"
        "https://github.com/be5invis/Iosevka/releases/download/v34.8.1/PkgTTC-SGr-IosevkaTermSlab-34.8.1.zip"
        "https://github.com/be5invis/Iosevka/releases/download/v34.8.1/PkgTTC-SGr-IosevkaSlab-34.8.1.zip"
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/SourceCodePro.zip"
        "https://github.com/source-foundry/Hack/releases/download/v3.003/Hack-v3.003-ttf.tar.gz"
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/RobotoMono.zip"
    )

    echo -e "\n${CYAN}Synchronizing fonts...${RESET}"
    _TMP_DIR=$(mktemp -d)

    for url in "${URLS[@]}"; do
        filename=$(basename "$url")
        filename="${filename%%\?*}"
        folder_name=$(echo "$filename" | sed -e 's/\.zip$//' -e 's/\.tar\.gz$//')
        target_dir="$_FONT_DIR/$folder_name"

        # Print the font name and immediately drop to the next line (\n)
        printf "  %-45s \n" "$folder_name"

        if [ -d "$target_dir" ]; then
            # Move up 1 line (\e[1A), print SKIP aligned, clear line below (\e[K)
            printf "\e[1A\r  %-45s [ ${YELLOW}SKIP${RESET} ]\n\e[K" "$folder_name"
            continue
        fi
        
        # wget outputs a clean progress bar on the current line
        if wget -q --show-progress -O "$_TMP_DIR/$filename" "$url"; then
            
            # Extract silently
            mkdir -p "$target_dir"
            case "$filename" in
                *.zip)
                    unzip -q -o "$_TMP_DIR/$filename" -d "$target_dir"
                    ;;
                *.tar.gz|*.tgz)
                    tar -xzf "$_TMP_DIR/$filename" -C "$target_dir"
                    ;;
                *)
                    mv "$_TMP_DIR/$filename" "$target_dir/"
                    ;;
            esac
            
            # MAGIC: Move up 2 lines (\e[2A), overwrite with DONE, move down, clear old progress bar (\e[K)
            printf "\e[2A\r  %-45s [ ${GREEN}DONE${RESET} ]\n\e[K" "$folder_name"
        else
            # MAGIC: Move up 2 lines (\e[2A), overwrite with FAIL, move down, clear old progress bar (\e[K)
            printf "\e[2A\r  %-45s [ ${RED}FAIL${RESET} ]\n\e[K" "$folder_name"
        fi
        
        rm -f "$_TMP_DIR/$filename"
    done

    rm -rf "$_TMP_DIR"

    echo -ne "\n${CYAN}Updating system font cache... ${RESET}"
    fc-cache -f -v > /dev/null
    echo -e "${GREEN}DONE${RESET}"

    echo -e "${BOLD}${GREEN}:: Fonts setup complete!${RESET}\n"
}


# _CODE="$HOME/.config/Code/User/settings.json"
# if [ -f $_CODE ]; then
#     echo "removing $_CODE" && rm -r $_CODE
# else
#     echo "not found $_CODE"
# fi
# echo "creating symbolic link: $_CODE " && ln -s $PWD/vsCode/settings.json $_CODE
# echo

# _XFCONF="$HOME/.config/xfce4/xfconf"
# if [ -d $_XFCONF ]; then
#     echo "removing $_XFCONF" && rm -r $_XFCONF
# else
#     echo "not found $_XFCONF"
# fi
# echo "creating symbolic link: $_XFCONF " && ln -s $PWD/xfconf $_XFCONF
# echo -e "\033[0;31m----------> run 'grep -rEI "sumit" --exclude-dir=.git .' command and change user <--------------\033[0m"
# echo

# ZSH_RC="$HOME/.zshrc"
# if [ -f $ZSH_RC ]; then
#     echo "removing $ZSH_RC" && rm $ZSH_RC
# else
#     echo "not found $ZSH_RC"
# fi
# echo "creating symbolic link: .zshrc" && ln -s $PWD/zshrc $ZSH_RC
# echo

# # VSCode
# # sudo apt install shfmt


function setup_tldr() {
    echo "tldr: "
    apt_install tldr tealdeer
    
    if command -v tldr &>/dev/null; then
        echo -e "\nUpdating tldr database..."
        tldr --update
    else
        echo -e "\nFailed to install tldr. Skipping update."
    fi

    echo
}



main() {
    # sudo apt-get update
    # echo
    # pipx upgrade-all
    # echo
    # setup_syncthing
    # setup_conan
    # setup_grub
    # setup_kitty
    # setup_neovim
    # setup_tlp
    # setup_tmux
    # setup_tldr
    # apt_install wget2
    # apt_install inkscape
    setup_fonts
}

main "$@"