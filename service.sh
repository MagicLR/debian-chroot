#!/system/bin/sh

sleep 60

ROOTFS=/data/local/debian
LOG=$ROOTFS/boot.log

# 内置存储挂载
mkdir -p $ROOTFS/mnt/storage
mountpoint -q $ROOTFS/mnt/storage || {
    mount --bind /storage/emulated/0 $ROOTFS/mnt/storage
    mount --make-rslave $ROOTFS/mnt/storage
}

# ===== SD 卡挂载 =====

SD_REAL=/mnt/media_rw/B378-80C5
SD_FUSE=/storage/emulated/0
TARGET=$ROOTFS/mnt/sdcard

mkdir -p $TARGET

if mountpoint -q $TARGET; then
    echo "SD already mounted"
else
    if [ -d $SD_REAL ]; then
        echo "Mounting real block device..."
        mount --bind $SD_REAL $TARGET
    elif [ -d $SD_FUSE ]; then
        echo "Fallback to fuse layer..."
        mount --bind $SD_FUSE $TARGET
    else
        echo "SD not found"
    fi

    mount --make-rslave $TARGET
fi

mount --make-rprivate /

# dev
mountpoint -q $ROOTFS/dev || {
    mount --rbind /dev $ROOTFS/dev
    mount --make-rslave $ROOTFS/dev
}

# devpts
mountpoint -q $ROOTFS/dev/pts || \
    mount -t devpts devpts $ROOTFS/dev/pts -o gid=5,mode=620

# proc
mountpoint -q $ROOTFS/proc || \
    mount -t proc proc $ROOTFS/proc

# sys
mountpoint -q $ROOTFS/sys || {
    mount --rbind /sys $ROOTFS/sys
    mount --make-rslave $ROOTFS/sys
}

# tmp
mountpoint -q $ROOTFS/tmp || {
    mount -t tmpfs tmpfs $ROOTFS/tmp
    chmod 1777 $ROOTFS/tmp
}

[ -f $ROOTFS/etc/resolv.conf ] || \
echo "nameserver 8.8.8.8" > $ROOTFS/etc/resolv.conf

chroot $ROOTFS /usr/bin/env -i \
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
HOME=/root \
TERM=xterm-256color \
/bin/bash -c "
/etc/init.d/ssh start >> /var/log/ssh/boot.log 2>&1
[ -f /etc/init.d/bt ] && /etc/init.d/bt start >> /var/log/bt/boot.log 2>&1
nohup tail -f /dev/null >/dev/null 2>&1 &
"