#!/bin/bash
set -e

echo "syncthing: "
if [ ! command -v syncthing ] &>/dev/null; then
    echo "Installing syncthing..."
    sudo apt-get update && sudo apt-get install -y syncthing
fi
if ! systemctl is-active --quiet syncthing@$USER.service; then
    sudo systemctl enable --now syncthing@$USER.service
    sudo systemctl start syncthing@m$USER.service
fi
echo

_CONAN="$HOME/.conan2/profiles"
if [ -d $_CONAN ]; then
    echo "removing $_CONAN" && rm -r $_CONAN
else
    echo "not found $_CONAN"
fi
echo "creating symbolic link: $_CONAN " && ln -s $PWD/conan $_CONAN
echo

_GRUB=/usr/share/grub/themes/Elegant-forest-window-left-dark
if [ -d $_GRUB ]; then
    echo "removing $_GRUB" && sudo rm -r $_GRUB
else
    echo "not found $_GRUB"
fi
echo "creating symbolic link: $_GRUB " && sudo ln -s $PWD/Elegant-forest-window-right-dark $_GRUB
sudo update-grub
echo

KITTY="$HOME/.config/kitty"
if [ -d $KITTY ]; then
    echo "removing $KITTY" && rm -r $KITTY
else
    echo "not found $KITTY"
fi
echo "creating symbolic link: $KITTY " && ln -s $PWD/kitty $KITTY
echo

_NVIM="$HOME/.config/nvim"
if [ -d $_NVIM ]; then
    echo "removing $_NVIM" && rm -r $_NVIM
else
    echo "not found $_NVIM"
fi
echo "creating symbolic link: $_NVIM " && ln -s $PWD/nvim $_NVIM
echo

# _SILENT=$PWD/silent/install.sh
# if [ ! command -v sddm ] &>/dev/null; then
#     echo "Installing sddm"
#     sudo apt-get install -y sddm
# fi
# $_SILENT
# echo

_TLP="/etc/tlp.d"
if [ -d $_TLP ]; then
    echo "removing $_TLP" && sudo rm -r $_TLP
else
    echo "not found $_TLP"
fi
echo "creating symbolic link: $_TLP " && sudo ln -s $PWD/tlp/tlp.d $_TLP
sudo systemctl enable --now tlp.service
sudo systemctl enable tlp-pd.service
echo

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

_CODE="$HOME/.config/Code/User/settings.json"
if [ -f $_CODE ]; then
    echo "removing $_CODE" && rm -r $_CODE
else
    echo "not found $_CODE"
fi
echo "creating symbolic link: $_CODE " && ln -s $PWD/vsCode/settings.json $_CODE
echo

_XFCONF="$HOME/.config/xfce4/xfconf"
if [ -d $_XFCONF ]; then
    echo "removing $_XFCONF" && rm -r $_XFCONF
else
    echo "not found $_XFCONF"
fi
echo "creating symbolic link: $_XFCONF " && ln -s $PWD/xfconf $_XFCONF
echo -e "\033[0;31m----------> run 'grep -rEI "sumit" --exclude-dir=.git .' command and change user <--------------\033[0m"
echo

ZSH_RC="$HOME/.zshrc"
if [ -f $ZSH_RC ]; then
    echo "removing $ZSH_RC" && rm $ZSH_RC
else
    echo "not found $ZSH_RC"
fi
echo "creating symbolic link: .zshrc" && ln -s $PWD/zshrc $ZSH_RC
echo

# VSCode
# sudo apt install shfmt
