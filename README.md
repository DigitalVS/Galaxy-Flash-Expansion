# Galaxy Flash Expansion

Galaxy Flash Expansion is a USB flash drive (thumb drive, memory stick) expansion board for retro computer [Galaksija](https://en.wikipedia.org/wiki/Galaksija_(computer)) (eng. Galaxy). It supports classical Galaksija computers where it is connected via expansion port, and new Galaksija 2024 with expansion board plugged to the CPU socket. Classical Galaksija expansion board features 32 kilobyte RAM expansion as well.

This project contains all hardware description files and software files required for making such expansion boards. All contents is published in an open-source manner and you are free to make it on your own, or you can order assembled and tested boards from the author himself by contacting him via email address provided for this GitHub account.

The source code is written in Z80 assembly language and is almost identical for both Galaksija versions, but hardware part is quite distinct and to differentiate these two versions, they are named differently:

- __Galaxy Space Expansion (GSE)__ - board name for classical Galaksija
- __Galaxy Flash Expansion (GFE)__ - board name for newer Galaksija 2024

> Approximate speed measurements show impressive speed results for such underpowered computer. With screen refresh disabled, data reading speed is roughly in the range of 80-100 kilobytes per second.

Next image shows a (non root) directory contents example. Note that long file names are shortened to eight characters with `>1` at the end of the name. In case of multiple files with equal six characters at the beginning of the name, suffixes are also `>2`, `>3`, and so on. At the end of line is file size value in bytes. For files larger then 9999 bytes, size is displayed in kilobytes with latter `K` at the end (eg. `123K`), or even in megabytes with letter `M`. Directory listings with file(s) larger then one gigabyte are not supported.

![Directory listing example.](/images/usb_flash_screen.png)

> Expansion board USB Type-A connector is not an universal USB connector and other devices than flash drives (and possible external USB hard drives), when plugged to the connector, will not work!

## Hardware Features

Main feature of both versions of expansion boards - USB flash drive support, is implemented with CH376S "file manage and control" chip, which supports drives in FAT12, FAT16 and FAT32 format up to 32GB. USB hard disks with FAT32 should work, too.

The rest of the functionality is different for Galaxy Space Expansion and Galaxy Flash Expansion boards and will be described separately.

> Before installing the GSE or GFE board, ensure that your Galaksija is turned-off. Installing the board to a powered-on computer may damage electronic components both on the computer side, as well as on the GSE/GFE boards.

### Galaxy Space Expansion

Galaxy Space Expansion additionally contains one 32 kilobyte RAM chip and one EPROM chip. Former chip is a RAM expansion chip which in conjunction with existing 6 kilobytes on the main computer PCB makes one continuous 38 kilobyte memory space. Latter chip contains software for communication with USB drive (and something more that will be presented later in the text). These two chips are visible to the CPU at following address ranges:

- RAM: &4000 - &BFFF
- EPROM: &C000 - &FFFF

Software must be initialized before use every time computer is powered on by issuing the following command in the BASIC prompt: `A=USR(&C000)`.

Next image shows two versions of the GSE PCBs. Main difference between them is that one is with SRAM chip in PDIP package (larger board) and the other with SRAM chip in TSOP package (smaller board). Schematics, Gerber and all other necessary files for both versions are published here on this repository.

![Two GSE version boards look.](/images/two-gse-versions.png)

Minimal system requirements for GSE board are ROM A and ROM B with 6 kilobytes of RAM present. Without all 6 kilobytes of base RAM, additional RAM won't make continuous memory space and will not be usable in most cases.

#### Board Installation Instructions

Galaxy Space Expansion board is supposed to be plugged in the Galaksija's 44-pin edge card expansion slot. For those who don't have small edge card board with expansion slot already installed on the Galaksija's main PCB, production files are provided at [Galaksija Resources](https://github.com/DigitalVS/Galaksija-Resources) repository, or may be ordered together with GSE board. This small board is made to be backward compatible with original edge card PCBs designed for original Galaksija in year 1984, but features additional signals which are missing on the original board. For GSE board to function properly, three of these additional signals must be present on the expansion connector: power supply (VCC), read (RD) CPU signal and RESET CPU signal.

Bringing these three missing signals to expansion connector is not too hard and does not require any special skills or equipment. You'll need a peace of isolated wire (not too thin, nor too thick), soldering wire and a soldering iron.

Edge card board from Galaksija Resources repository already has soldering pads labeled VCC, RD- and RESET-. These are the points where you'll solder one side of the wires. The other side of VCC wire is best to solder somewhere as close to power supply input socket as possible, to one of the points where VCC is available. RD signal is best to take directly from CPU pin number 21, from underneath of main PCB. The other side of RESET wire may be connected to CPU pin 26, or to some of the reset points closer to the edge connector. For example, the next picture shows edge card board with RESET signal taken from the nearby reset push button.

![Expansion port example.](/images/port-example.png)

For those who already have some kind of expansion connector attached to the Galaksija's main PCB, first thing to check is to determine are there additional signals already brought to this connector and, if that's the case, which signals to which pins are connected. Pins for three additional signals (strictly speaking VCC is not a signal, but alright) VCC, RD and RESET are chosen to be at the same pins as they were put by some very old projects, so there is some small possibility that some of these three signals are already connected to correct pins. Compare pins on your board with the pin numbers for VCC, RD and RESET on the edge connector at Galaksija Resources repository and if you don't have these signals connected to the correct pins, connect them as it is described for those who didn't have expansion connector on their main PCB.

All of this may seam as too hard for someone unexperienced in soldering and electronics in general, but success will be awarded with much improved and much more functional old Galaksija computer.

### Galaxy Flash Expansion

New Galaksija 2024 has more RAM and ROM then old Galaksija, and it does not have any free space left in the memory map. Luckily, there is a lot of unused space in the built-in EPROM chip and all the software for this project has been put in there. Drawback is that existing EPROM chip must be reprogrammed or replaced, but, on the other hand, software will be initialized automatically and no additional initialization steps are needed after every computer startup.

#### Board Installation Instructions

Installation of the Galaxy Flash Expansion board is easier then installation of the Galaxy Space Expansion board. Here is assumed that everyone has a Z80 processor installed into a socket and not soldered directly to the PCB. If this is not so in your case, you'll have to first desolder the processor and solder the 40-pin socket in its place.

First, pull carefully Z80 CPU from the socket. If you do not have a dedicated tool for this, you may use small flat screwdriver. Try to pull CPU upwards evenly on both sides by one or two millimeters at the time to avoid bending pins on the chip. If some of the pins end up bended, it's not a big deal, carefully and without too much force, bring them back to their correct position. You may use needle nose pliers or flat screwdriver to accomplish this.

Now you need to push GFE board into the CPU socket and to put CPU into CPU socket of the GFE board. GFE board can be installed only in one position (there is no room to install it in inverse orientation), so it is not possible to install it in the wrong way, but for CPU take care that it is installed in correct orientation. It needs to be installed in the same orientation as it was installed previously when it was in the socket. The correct orientation is also labeled on the GFE board.

The size of the GFE board is so small that once it is installed it practically doesn't need to be removed ever again.

Following image shows GFE board installed into the Galaksija's CPU slot. Two logical ICs are on the back side of the board, underneath the CPU and are not visible on the picture.

![GFE board look.](/images/installed-gfe.png)

> Don't forget to also replace or reprogram BASIC EPROM chip on the left side of the motherboard (labeled as U3) because GFE won't work otherwise.

## Software Features

Only USB flash drives with FAT file system are supported. Operation is similar to MS-DOS, with a few differences.

Filenames follow the MS-DOS standard 8+3 name plus extension format (eg. "filename.txt"). Long filenames are not supported. Directory levels are separated with `/` (slash). Extensions `.BAS`, `.GTP`, `.BIN` and `.TXT` are recognized file types. Files with any other extension are not allowed. Extension is mandatory part of the filename.

Extension `.BAS` is for BASIC programs, while `.GTP` extension is support for popular Galaksija file format for machine language programs or combination of BASIC and machine language programs. Extension `.BIN` is for raw binary files, `.TXT` is treated the same way as `.BIN` but was added so that user can easier distinguish data saved in the file.

The path is limited to 36 characters, which is minimum of four directory levels. Files can only be accessed in the current directory (eg. "path/filename.txt" is not a valid filename). You can move between directory levels using `CD` command, which accepts an entire path (eg. "subdir1/subdir2/subdir3"). If the path starts with a `/` then it starts from the root, otherwise it is relative to the current directory. Command parameter `..` moves current directory one level up, `.` stands for the current directory.

MS Windows uses the `~` (tilde) character to create the short versions of long filenames but that character does not exist on the Galaksija. Character `>` has been used instead.

All low level USB subroutines are exposed with a jump table, so that other programs may use it to implement its own data reading and/or writing functionality.

### Commands

Small set of commands is implemented to handle all necessary communication with USB flash drives. These commands are:

| Command | Description
|------|---------------
| CAT | Lists current directory contents
| FLOAD | Loads file from flash drive into the memory
| FSAVE | Saves memory contents to the flash drive
| CD  | Sets current directory
| REMOVE | Removes the file from the flash drive
| MKDIR | Creates new directory
| RMDIR | Removes the directory
| GAD  | Starts the Galaksija debugging application

Parameters in parentheses are optional parameters (though not always for all cases).

> When parameter is stated under the quotes, and there are no additional parameters behind it, ending quote character is optional.

#### CAT ("\<wildcard\>")

Display detailed current directory listing. Parameter "\<wildcard\>" is optional. Wildcard characters `?` and `*` are used to filter filenames, eg. `CAT "*.BAS"` shows only filenames with BAS extension.

>To be able to view long directory listings, __directory entries are printed on the screen only as long as ENTER key is held down__. This means that it is possible to list part of directory contents by holding the ENTER key pressed, then to release ENTER key and to  review displayed listing, then to continue listing  more directory entries by pressing ENTER key again or to stop listing process by pressing a BREAK key (BREAK key is usually labeled as ESC on newer Galaksija keyboards).

This command does not show hidden files and directories.

> Keyword `DIR` is already used as a command name in new Galaksija 2024 computer. Thus it could not be used here and name `CAT` (short for catalog) has been chosen instead.

#### FLOAD "filename(",\<address\>)

Load "filename" file into specified memory location. Parameter \<address\> is a decimal or hexadecimal value.

Supported extensions are `.BAS`, `.GTP`, `.BIN` and `.TXT`. Parameter \<address\> is mandatory for `.BIN` and `.TXT`, for `.BAS` and `.GTP` it is optional and if it exists than it is ignored.

#### FSAVE "filename(",\<address\>,\<length\>)

Save memory content to file on USB flash drive. Parameters \<address\> and \<length\> are a decimal or hexadecimal value.

Supported extensions are `.BAS`, `.GTP`, `.BIN` and `.TXT`. Parameter \<address\> is mandatory for `.GTP`, `.BIN` and `.TXT`, for `.BAS` it is optional and if it exists than it is ignored. Parameter \<length\> is mandatory if \<address\> parameter is present.

#### CD ("path")

Change current directory. Parameter "path" is optional. If not provided, the current directory path is printed on the screen.

EXAMPLES:

`CD "/"`  changes current directory to root directory\
`CD ".."` changes current directory one level up\
`CD "."` access current directory (use to check that directory is present on current disk)\
`CD` prints current path.

#### REMOVE "filename"

Delete a file from the USB flash drive.

> Be aware that this command does not ask for confirmation before deleting and that once deleted file cannot be recovered back again.

#### MKDIR "dirname"

Create new directory at current path. If created successfully, then it's open.

#### RMDIR "dirname"

Remove the directory. Directory has to be empty before deleting.

#### GAD

Start [GAD](https://github.com/DigitalVS/GAD) debugging application. This application is useful for debugging Z80 assembly code and is not related to other commands listed here. It does not depend on GSE/GFE hardware and can be used independently on any Galaksija or in emulator program as well. See GAD documentation for more details.

## Troubleshooting

Some flash drives are reported to not work with CH376 but author of this project did not find such drive.

Some older CH376 revisions (but still widely sold) are proved to not recognize flash drives formatted on Windows operating system (especially Windows 10). In case that you have one of these, try to format flash drive to FAT32 file system on Linux/Mac (e.g. with GParted) or with some of non built-in Windows formatting tools.

If while issuing any of the commands you're getting `NO CH376` message, that means that computer does not recognize the board. In that case check if PCB is pushed all the way in the CPU socket (for GFE board) or on expansion slot (for GSE board). Try to power cycle the computer. Try to reseat it (with computer turned off).

Error message `NO USB` is issued in case that USB flash drive is not inserted in the USB slot.

The MIT License (MIT)

Copyright (c) 2025 Vitomir Spasojević (<https://github.com/DigitalVS/Galaxy-Flash-Expansion>). All rights reserved.
