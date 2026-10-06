newaction {
  trigger     = "configure",
  description = "Downloads and configures required dependencies which are not included in the repo"
}

workspace "cybervisionrpc"
  architecture "x64"
  configurations { "Debug", "Release", }

include "src/red4ext"
