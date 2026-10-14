# Curated built-in shader packs for ReShade on Linux Vulkan
pkgs: {
  legacy = {
    name = "legacy";
    description = "Standard ReShade shader repository by crosire";
    src = pkgs.fetchFromGitHub {
      owner = "crosire";
      repo = "reshade-shaders";
      rev = "bcb5ba54199f4455026dd8ba66dc1b74461d3152";
      hash = "sha256-R8H127h/xiIgAogh6KjOA3Yg3A0dp6s6EjVnlnN1rRQ=";
    };
    shadersSubdir = "Shaders";
    texturesSubdir = "Textures";
  };

  sweetfx = {
    name = "sweetfx";
    description = "SweetFX shader suite by CeeJay.dk (CeeJayDK)";
    src = pkgs.fetchFromGitHub {
      owner = "CeeJayDK";
      repo = "SweetFX";
      rev = "93ddf39b357f5da534ed6d34ba4ec8cc7dcfa361";
      hash = "sha256-7swuvINU8FvzT6SHj1U7av6H7p7Dxh5h0el7K7yUluE=";
    };
    shadersSubdir = "Shaders";
    texturesSubdir = "Textures";
  };

  quint = {
    name = "quint";
    description = "qUINT shader framework by Pascal Gilcher (Marty McFly / martymcmodding)";
    src = pkgs.fetchFromGitHub {
      owner = "martymcmodding";
      repo = "qUINT";
      rev = "98fed77b26669202027f575a6d8f590426c21ebd";
      hash = "sha256-nPraJgxDm1N9FIhrv0msI3B3it8uyzk6YoX25WY27gE=";
    };
    shadersSubdir = "Shaders";
    targetShadersSubdir = "qUINT";
  };

  prod80 = {
    name = "prod80";
    description = "Color correction and grading shaders by prod80";
    src = pkgs.fetchFromGitHub {
      owner = "prod80";
      repo = "prod80-ReShade-Repository";
      rev = "1c2ed5b093b03c558bfa6aea45c2087052e99554";
      hash = "sha256-EM9WxpbN0tUB9yjZFwWtY1l8um7jvMfC2eenEl2amF8=";
    };
    shadersSubdir = "Shaders";
    texturesSubdir = "Textures";
    targetShadersSubdir = "prod80";
    targetTexturesSubdir = "prod80";
  };

  otisfx = {
    name = "otisfx";
    description = "OtisFX cinematic shaders and camera tools by Frans Bouma (Otis_Inf)";
    src = pkgs.fetchFromGitHub {
      owner = "FransBouma";
      repo = "OtisFX";
      rev = "193aa0bf07ee82fbd5f142b5b813b19c5d169745";
      hash = "sha256-vP9on1fXVuP5zrEUU3tPNlTkftI7V84YPLebdNk2Yo0=";
    };
    shadersSubdir = "Shaders";
    texturesSubdir = "Textures";
    targetShadersSubdir = "OtisFX";
    targetTexturesSubdir = "OtisFX";
  };

  fubax = {
    name = "fubax";
    description = "Fubax optical and styling shaders by Fubaxiusz";
    src = pkgs.fetchFromGitHub {
      owner = "Fubaxiusz";
      repo = "fubax-shaders";
      rev = "d902cc2e8216f10801019b02b09f7bd55449fd79";
      hash = "sha256-901Nia6BVBeioUlMEy9FphX+SShEsWjhg63xSSMMjBc=";
    };
    shadersSubdir = "Shaders";
    texturesSubdir = "Textures";
    targetShadersSubdir = "fubax";
    targetTexturesSubdir = "fubax";
  };

  astrayfx = {
    name = "astrayfx";
    description = "AstrayFX clarity and depth shaders by BlueSkyDefender (Clarity.fx)";
    src = pkgs.fetchFromGitHub {
      owner = "BlueSkyDefender";
      repo = "AstrayFX";
      rev = "59bae8b33e34f37a8e521e666864085ccbf08535";
      hash = "sha256-Lgm6QqNnL9sdJ8fCuBguezW7WScYcdmpEnxMChCpjko=";
    };
    shadersSubdir = "Shaders";
    texturesSubdir = "Textures";
    targetShadersSubdir = "AstrayFX";
    targetTexturesSubdir = "AstrayFX";
  };

  immerse = {
    name = "immerse";
    description = "iMMERSE Marty's Mods (Sharpen, SMAA) by Pascal Gilcher (martymcmodding)";
    src = pkgs.fetchFromGitHub {
      owner = "martymcmodding";
      repo = "iMMERSE";
      rev = "f57d3afa1ebe5d1fd6152d4f6fb9a2e75bd1d1cb";
      hash = "sha256-xw92HIZVQx1H2h9/PYIPt5v7ew+NnxIf8lYcPM0PjVs=";
    };
    shadersSubdir = "Shaders";
    texturesSubdir = "Textures";
    targetShadersSubdir = "iMMERSE";
    targetTexturesSubdir = "iMMERSE";
  };

  gshade = {
    name = "gshade";
    description = "GShade & PPFX Bloom collection by Mortalitas and community";
    src = pkgs.fetchFromGitHub {
      owner = "Mortalitas";
      repo = "GShade-Shaders";
      rev = "99abfa46d4b2ccd3810f7c09ccd776974eead9bc";
      hash = "sha256-LF3W8CB+S7Do/vLbLT4muifwxo1Ih3ii8gQDn/tmEKc=";
    };
    shadersSubdir = "Shaders";
    texturesSubdir = "Textures";
    targetShadersSubdir = "GShade";
    targetTexturesSubdir = "GShade";
  };

  reshadeTextures = {
    name = "reshadeTextures";
    description = "Consolidated textures and LUTs collection curated by Bhhl";
    src = pkgs.fetchFromGitHub {
      owner = "Bhhl";
      repo = "Reshade-NewFinalRender-textures";
      rev = "659250ecf22fed6799c22510bbb77e67f74292c7";
      hash = "sha256-uAlV02S3Q2eUWrpRNhhMAWemJtorTM5ruHMtAaZ4THM=";
    };
    texturesSubdir = "";
  };

  barbatos = {
    name = "barbatos";
    description = "Barbatos shaders (XeGTAO, SSR, DLAA-T, GI) by BarbatosAWLS";
    src = pkgs.fetchFromGitHub {
      owner = "BarbatosAWLS";
      repo = "Reshade-Shaders";
      rev = "1adf127d81fc0fdb9941bfb32a93fb46cc594770";
      hash = "sha256-+h5YrcehnORRJhTvXclvxPOFUzemTjGWL2Pws3OP+gE=";
    };
    shadersSubdir = "Shaders";
    texturesSubdir = "Textures";
    targetShadersSubdir = "Barbatos";
    targetTexturesSubdir = "Barbatos";
  };
}
