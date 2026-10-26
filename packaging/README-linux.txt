Mud Clarity
===========

Visualizes Riftshadow MUD area files: rooms, how they connect, and what is
wrong with them.

Requirements
------------
SDL3 3.2 or newer, and a Vulkan driver, from your distribution. They are
not included: install them with your package manager and keep them up to
date, as you would any other library. For example:

    Ubuntu 26.04 or newer, Debian 13:  sudo apt install libsdl3-0 libvulkan1
    Fedora:                            sudo dnf install SDL3 vulkan-loader
    Arch:                              sudo pacman -S sdl3 vulkan-icd-loader

Older releases (such as Ubuntu 24.04) don't package SDL3 and can't run this
build.

Running
-------
    ./mudclarity                      Open the window
    ./mudclarity open area.lst        Open the window on a world
    ./mudclarity area.lst             Check a world from the command line
    ./mudclarity help                 All the commands

In the window, press F1 for help and the keyboard shortcuts.

LICENSE.txt is Mud Clarity's licence (MIT).
