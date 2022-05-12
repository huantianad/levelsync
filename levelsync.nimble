# Package

version       = "2.0.4"
author        = "huantian"
description   = "Automatically download and update your Rhythm Doctor levels!"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["levelsync"]


# Dependencies

requires "nim >= 1.6.4"
requires "yaml >= 0.16.0"
requires "zippy >= 0.9.8"
requires "chronicles >= 0.10.2"
