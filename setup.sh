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

    _TMUX="$HOME/.config/tmux"
    if [ -d $_TMUX ]; then
        echo "removing $_TMUX" && rm $_TMUX
    else
        echo "not found $_TMUX"
    fi
    echo "check acpi command:"
    if ! command -v acpi >/dev/null 2>&1; then
        echo "acpi command not found " && sudo apt-get install acpi
    fi
    echo "creating symbolic link: tmux " && ln -s $PWD/tmux $_TMUX
    echo
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

main() {
    sudo apt-get update
    echo
    pipx upgrade-all
    echo
    # setup_syncthing
    # setup_conan
    # setup_grub
    # setup_kitty
    # setup_neovim
    # setup_tlp
}

main "$@"