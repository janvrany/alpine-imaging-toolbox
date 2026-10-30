# Alpine building toolbox

A set of reusable scripts to help building Alpine images.

For a long time, I've been using [similar scripts for Debian][1] to build
various images. Recently (2026) I decided to try out Alpine for some
containers.

To give credit where credit is due: the crux of Alpine bootstrapping is
taken from [@sfan5's alpine-container.sh][2].

## Sister project

As mentioned above, there's a sister project - [debian-imaging-toolbox][1].

## Prerequisites

 1. [alpine-chroot-install][3]
 2. `run-parts`

On Debian do: `apt install debianutils alpine-chroot-install`

## !!! BIG FAT WARNING !!!

Scripts in this repository do use `sudo` quite a lot. **IF THERE'S A BUG,
IT MAY WIPE OUT YOUR SYSTEM**. **DO NOT RUN THESE SCRIPTS WITHOUT READING
THEM CAREFULLY FIRST**.

I tried to make do without `sudo`, couple times actually, but always failed
and given up. Maybe I'll try again, until then: *check scripts or hope
for the best!*

## Scripts

 * `./build.sh <root image>`

   Installs bootable Debian system into given *root image* (see section
   *Root image* below on root images). This also executes all customization
   hooks located in `build-hooks` directory located next to `./build.sh`
   script.

 * `run-shell.sh <root image>`

   Runs a shell within the image using [systemd-nspawn][6]

 * `run-container.sh <root image>`

   Boots up the image as a container using [systemd-nspawn][6].

## Root image

Scripts in this repository takes *root image* as their first parameter.
The root image might be:

 * A directory. In this case the entire debian system is installed
   into that directory, effectively creating a Debian chroot.

 * A block device containing a ext4 filesystem.

 * A local file containing a disk image in any format supported by
   [libguestfs][4] (including raw images).

   To create a non-partitioned raw ext4 disk image:

   ```sh
   truncate -s 10G root.img
   /sbin/mkfs.ext4 root.img
   ```

   To create partitioned `.qcow2` disk image:

   ```sh
   qemu-img create -f qcow2 root.qcow2 10g
   guestfish -a root.img run : part-disk /dev/sda mbr : part-set-bootable /dev/sda 1 true : mkfs ext4 /dev/sda1
   ```

 * An URL pointing to remote disk image - see section
   [Adding remote storage][5].

   This works in theory, but it is painfully slow.

[1]: https://github.com/janvrany/debian-imaging-toolbox
[2]: https://gist.github.com/sfan5/52aa53f5dca06ac3af30455b203d3404
[3]: https://github.com/alpinelinux/alpine-chroot-install/
[4]: https://libguestfs.org/
[5]: https://libguestfs.org/guestfish.1.html#adding-remote-storage
[6]: https://www.freedesktop.org/software/systemd/man/systemd-nspawn.html