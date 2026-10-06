include "libs"

project "cybervisionrpc"
  kind "SharedLib"
  language "C++"
  cppdialect "C++20"

  location "build"
  targetdir "%{prj.location}/%{cfg.buildcfg}"

  includedirs {
    "include",
    "libs/RED4ext.SDK/include",
    "libs/discord_game_sdk/cpp",
  }

  files { "src/CyberVisionRPC/**.cpp", "include/CyberVisionRPC/**.h" }
  links "discord_game_sdk"

  filter "toolset:gcc"
    buildoptions { "-Wall", "-Wextra", "-Wpedantic", "-Werror", }

  filter "toolset:msc"
    buildoptions { "/W4", "/WX", }

  filter "configurations:Debug"
    defines "CyberVisionRPC_DEBUG"
    symbols "On"

  filter "configurations:Release"
    optimize "Speed"
