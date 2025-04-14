<p align="center">
  <img src="logo.png"/>
</p>

*Lightly* is a fork of breeze theme style that aims to be visually modern and minimalistic. 

## Development ⚠️

Lightly is a work in progress theme, there is still a lot to change, so expect bugs! Some applications may suddenly crash or flicker.

If you have any feedback or encounter some bugs, feel free to open an issue or a pr.


## Screenshots

![default](https://github.com/Luwx/Lightly/blob/master/Lightly-default.png)

With transparent dolphin view off and no sidebar transparency:
![custom](https://github.com/Luwx/Lightly/blob/master/Lightly-custom.png)

With a full glass color scheme (currently full glass color schemes are very buggy and not fully supported):
![fullglass](https://github.com/Luwx/Lightly/blob/master/Lightly-fullglass.png)

## Configuration

![config page](https://github.com/Luwx/Lightly/blob/master/config.png)

Lightly configuration page can be found in the KDE system settings under the Application style section. 


Most of these options are inherited from Breeze style, but Lightly has a few exclusive options that are enabled by default, including:

* Transparent Dolphin view (under the **frames** tab). This option disables the background and shadows of Dolphin view widget and draws top and bottom separators when the view has scrollable content.

*  Sidebar opacity (under the **transparency** tab). By default, it's 60. If it's bellow 100, shadows will be drawn automatically. 

The toolbar and menubar will follow the **titlebar** opacity. To configure the titlebar opacity, you will have to change the color scheme file directly in ~/.local/share/color-schemes. Open your desired color scheme and, in the ```[WM]``` section, add a fourth value to ```activeBackground``` and ```inactiveBackground```, like ```activeBackground=0,0,0,127``` where the last value is the alpha, that ranges from 0 (completely transparent) to 255 (totally opaque).

## Installation

### Installing Lightly from RPM repository on openSUSE Tumbleweed:

1. Add "nuklly" repository:
```sudo zypper ar -ef https://download.opensuse.org/repositories/home:nuklly/openSUSE_Tumbleweed/ nuklly```
2. Refresh repository list:
```sudo zypper ref```
3. You will be notified about received new repository key. And you will be asked if you want to accept the key. This repository is created on OBS. All builds are reproducible.
Type "```a```" and press enter.
4. Install Lightly:
```sudo zypper in lightly lightly-addons lightly-decoration liblightlycommon6```


## Manual installation

### Dependencies

#### openSUSE
```
sudo zypper install cmake gcc-c++ extra-cmake-modules libQt6Gui-devel libQt6DBus-devel libqt6-qttools-devel libqt6-qtx11extras-devel libQt6OpenGL-devel libQt6Network-devel libepoxy-devel kconfig-devel kconfigwidgets-devel kcrash-devel kglobalaccel-devel ki18n-devel kio-devel kservice-devel kinit-devel knotifications-devel kwindowsystem-devel kguiaddons-devel kiconthemes-devel kpackage-devel kwin5-devel xcb-util-devel xcb-util-cursor-devel xcb-util-wm-devel xcb-util-keysyms-devel
```


### Build and install

```
git clone --single-branch --depth=1 https://github.com/Luwx/Lightly.git
cd Lightly && mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_TESTING=OFF ..
make
sudo make install
```

### Uninstall

In the build folder:
```
sudo make uninstall
```

## Acknowledgments

Breeze authors and Kvantum developer Pedram Pourang.
