# Package

version       = "2.3.0"
author        = "huantian"
description   = "Automatically download and update your Rhythm Doctor levels!"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["levelsync"]


# Dependencies

requires "nim >= 2.2.4"
requires "yaml >= 2.2.0"
requires "zippy >= 0.10.16"
requires "chronicles >= 0.12.2"
requires "db_connector >= 0.1.0"
