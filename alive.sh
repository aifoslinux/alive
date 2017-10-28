#!/bin/bash

set -e -u

. /etc/alive.conf

run_as_root_only() {
    if [[ ${EUID} -ne 0 ]]; then
        echo "This script must be run as root."
        exit 1
    fi
}

ext_alive_default() {
    chroot work/rootfs /bin/sh -c "initctl enable elogind"
    chroot work/rootfs /bin/sh -c "initctl enable cgroupfs-mount"
}

set_alive_default() {
    chroot work/rootfs /bin/sh -c "initctl enable dhcpcd"

    if [ "$_SUPRA_" = 1 ]; then
        ext_alive_default
    fi
}

make_alive_now() {
    iso_version=$(date +%Y.%m.%d)
    iso_name="aifoslinux-infra-$iso_version.iso"

    if [ "$_SUPRA_" = 1 ]; then
        iso_name="aifoslinux-supra-$iso_version.iso"
    fi

    iso_label="aifos_$(date +%Y%m)"
    iso_publisher="AI\\OS <http://www.aifoslinux.org>"
    iso_application="AI\\OS Live/Rescue CD"

    mkdir -p work/rootfs/livecd
    mkdir -p work/rootfs/rootfs
    setup-chroot -m work/rootfs

    if [ "$_SUPRA_" = 1 ]; then
        add ${pkgs_supra[@]} rootdir=work/rootfs
    else
        add ${pkgs_infra[@]} rootdir=work/rootfs
    fi

    setup-chroot -u work/rootfs

    set_alive_default
    chroot work/rootfs /bin/sh -c "echo \"For the installation instructions,\" >> /etc/motd"
    chroot work/rootfs /bin/sh -c "echo \"read the /root/install.txt file\" >> /etc/motd"
    cp /share/alive/install.txt work/rootfs/root

    mkdir -p work/iso/LiveOS
    mksquashfs work/rootfs work/iso/LiveOS/rootfs.sfs \
        -noappend -comp xz -no-progress -b 1M -Xdict-size 100%

    mkdir work/iso/isolinux
    cp /lib/syslinux/bios/isolinux.bin work/iso/isolinux
    cp /lib/syslinux/bios/isohdpfx.bin work/iso/isolinux
    cp /lib/syslinux/bios/ldlinux.c32 work/iso/isolinux
    cp /lib/syslinux/bios/vesamenu.c32 work/iso/isolinux
    cp /lib/syslinux/bios/libcom32.c32 work/iso/isolinux
    cp /lib/syslinux/bios/libutil.c32 work/iso/isolinux
    sed "s|aifos|$iso_label|g" \
        /share/alive/isolinux.cfg > work/iso/isolinux/isolinux.cfg

    cp /boot/vmlinuz work/iso/isolinux
    mkinitramfs $kver work/iso/isolinux/initramfs

    truncate -s 10M work/iso/isolinux/efiboot.img
    mkdosfs -n ALIVE_EFI work/iso/isolinux/efiboot.img

    mkdir -p work/efiboot
    mount work/iso/isolinux/efiboot.img work/efiboot

    mkdir -p work/efiboot/EFI/{boot,fonts}
    cp /boot/efi/ai\\os/{boot,grub}x64.efi work/efiboot/EFI/boot
    cp /boot/efi/ai\\os/fonts/unicode.pf2 work/efiboot/EFI/fonts
    sed "s|aifos|$iso_label|g" \
        /share/alive/grub.cfg > work/efiboot/EFI/boot/grub.cfg

    umount -d work/efiboot

    mkdir -p work/iso/EFI/{boot,fonts}
    cp /boot/efi/ai\\os/{boot,grub}x64.efi work/iso/EFI/boot
    cp /boot/efi/ai\\os/fonts/unicode.pf2 work/iso/EFI/fonts
    sed "s|aifos|$iso_label|g" \
        /share/alive/grub.cfg > work/iso/EFI/boot/grub.cfg

    xorriso \
        -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "$iso_label" \
        -appid "$iso_application" \
        -publisher "$iso_publisher" \
        -preparer "prepared by alive" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -isohybrid-mbr work/iso/isolinux/isohdpfx.bin \
        -eltorito-alt-boot \
        -e isolinux/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -output "$iso_name" \
        work/iso

    rm -r work
}

run_as_root_only

_SUPRA_=0

for _grp in ${grps[@]}; do
    if [ "$_grp" = "infra" ]; then
        pkgs_infra+=(${pkgs[@]} infra)
    fi

    if [ "$_grp" = "infra-dev" ]; then
        pkgs_infra+=(infra-dev)
    fi

    if [ "$_grp" = "supra" ]; then
        _SUPRA_=1
        pkgs_supra=(${pkgs[@]} ${grps[@]})
    fi
done

if [ "$_SUPRA_" = 1 ]; then
    make_alive_now
    _SUPRA_=0
    make_alive_now
else
    make_alive_now
fi
