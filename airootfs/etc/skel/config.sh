#!/bin/bash

CONFFILE="config.sh"
ENVFILE="env.sh"

source /root/$ENVFILE

set_zoneinfo()
{
    echo "+++ Linking zoneinfo... +++"
    ln -s /usr/share/zoneinfo/$ZONEINFO /etc/localtime -f
}

enable_utc()
{
    echo "+++ Setting time... +++"
    hwclock --systohc --utc
}

set_language()
{
    echo "+++ Enabling language and keymap... +++"
    sed -i "s/#\($LANGUAGE\.UTF-8\)/\1/" /etc/locale.gen
    echo "LANG=$LANGUAGE.UTF-8" > /etc/locale.conf
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
    locale-gen
}

set_hostname()
{
    echo ""
    echo "+++ Creating hostname $HOSTNAME ... +++"
    echo $HOSTNAME > /etc/hostname
}

enable_networking()
{
    echo "+++ Enabling networking... +++"
    systemctl enable NetworkManager.service
}

enable_desktop_manager()
{
    echo "+++ Enabling display manager... +++"
    if [[ $DESKTOP_ENV == "KDE" ]]; then
        systemctl enable sddm.service
    elif [[ $DESKTOP_ENV == "GNOME" ]]; then
        systemctl enable gdm.service
    elif [[ $DESKTOP_ENV == "i3" ]]; then
        systemctl enable sddm.service
    fi
}

make_linux_image()
{
    echo ""
    echo "+++ Creating linux image... +++"
    mkinitcpio -p linux
}

configure_root_account()
{
    echo ""
    echo "+++ Setting root account... +++"
    chsh -s /bin/zsh
    passwd

    while (( $? != 0 )); do
        echo ""
        echo "Try again!"
        passwd
    done
}

set_user_account()
{
    echo ""
    echo "+++ Creating $USERNAME account... +++"
    useradd -m -G wheel -s /bin/zsh $USERNAME
    passwd $USERNAME

    while (( $? != 0 )); do
        echo ""
        echo "Try again!"
        passwd $USERNAME
    done

    echo ""
    echo "+++ Enabling sudo for $USERNAME ... +++"
    sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\ALL\)/\1/' /etc/sudoers

    echo ""
    echo "+++ Moving AUR Helper instalation script to user folder... +++"
    mv /root/yay_install.sh /home/$USERNAME/ -v
    chown $USERNAME:$USERNAME /home/$USERNAME/yay_install.sh -v
}

install_grub()
{
    grub-install $(findmnt / -o SOURCE | tail -n 1 | awk -F'[0-9]' '{ print $1 }') --force
    grub-mkconfig -o /boot/grub/grub.cfg
}

install_refind()
{
    # Bait refind-install into thinking that a refind install already exists,
    # so it will "upgrade" (install) in default location /boot/EFI/refind
    # This is done to avoid moving Microsoft's original bootloader.

    # Comment the following two lines if you have an HP computer
    # (suboptimal EFI implementation), or you don't mind moving
    # the original bootloader.
    mkdir -p /boot/EFI/refind
    cp /usr/share/refind/refind.conf-sample /boot/EFI/refind/refind.conf

    refind-install
    REFIND_UUID=$(cat /etc/fstab | grep UUID | grep "/ " | cut --fields=1)
    echo "\"Boot with standard options\"        \"root=${REFIND_UUID} rw initrd=/intel-ucode.img initrd=/amd-ucode.img initrd=/initramfs-linux.img\"" > /boot/refind_linux.conf
    echo "\"Boot with ASUS options\"        \"root=${REFIND_UUID} rw initrd=/intel-ucode.img initrd=/amd-ucode.img initrd=/initramfs-linux.img acpi_osi= acpi_backlight=native\"" >> /boot/refind_linux.conf
}

install_bootloader()
{
    echo ""
    echo "+++ Installing $BOOTLOADER bootloader... +++"

    if [ "$BOOTLOADER" == "grub" ]; then
        install_grub
    elif [ "$BOOTLOADER" == "refind" ]; then
        install_refind
    fi
}

clean_up()
{
    rm $CONFFILE -vf
    rm $ENVFILE -vf
}

prompt_finished()
{
    echo ""
    echo "+++++++++++++++++++++++++++++++++++++++++++++"
    echo "+++                                       +++"
    echo "+++  Setup finished! You can reboot now.  +++"
    echo "+++                                       +++"
    echo "+++++++++++++++++++++++++++++++++++++++++++++"
}

main()
{
    set_zoneinfo &&
    enable_utc &&
    set_language &&
    set_hostname &&
    enable_networking &&
    enable_desktop_manager &&
    make_linux_image &&
    configure_root_account &&
    set_user_account &&
    install_bootloader &&
    clean_up &&
    prompt_finished
}
# Execute main
main
