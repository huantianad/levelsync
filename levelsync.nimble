# Package

version       = "2.0.9"
author        = "huantian"
description   = "Automatically download and update your Rhythm Doctor levels!"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["levelsync"]


# Dependencies

requires "nim >= 2.0.8"
requires "yaml >= 2.1.1"
requires "zippy >= 0.10.15"
requires "chronicles >= 0.10.3"
requires "db_connector >= 0.1.0"
