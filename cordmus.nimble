# Package

version       = "0.1.0"
author        = "LordOfTrident"
description   = "Discord Rich Presence for Cmus written in Nim"
license       = "MIT"
srcDir        = "src"
bin           = @["cordmus"]


# Dependencies

requires "nim >= 2.0.4"
requires "discord_rpc"
requires "cligen"
