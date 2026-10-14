# nix-reshade-manager

Gerenciador declarativo de **ReShade** e coleções de shaders para **NixOS** e **Home Manager** com suporte nativo a Vulkan no Linux.

Compatível com jogos nativos Linux, Steam (Proton), Heronite, Heroic Games Launcher, Lutris, Flatpak e emuladores.

---

## ✨ Recursos

- **Injeção Nativa via Camada Vulkan**: Utiliza a camada implícita `VK_LAYER_RESHADE_overlay_x86_64`, ativada diretamente pela variável de ambiente `RESHADE=1` (ou `RESHADE_ENABLE=1`).
- **Filtro de Carregamento Transparente (`loader_filter.c`)**:
  - Evita interferência em launchers desktop nativos (Heroic, Lutris, Heronite, Steam).
  - Compatibilidade total com daemons do Wine/Proton (`explorer.exe`, `services.exe`, `winedevice.exe`).
  - Suporte completo a jogos Windows 64-bit e 32-bit (via Wine New WoW64 / `PROTON_USE_WOW64=1`).
- **Gerenciamento Declarativo de Shader Packs**:
  - Coleções integradas curadas ativáveis/desativáveis individualmente (crosire, SweetFX, qUINT, prod80, OtisFX, Fubax, AstrayFX, iMMERSE, GShade, Barbatos, Texturas).
  - Suporte a **packs customizados declarativos** via `extraPacks` (qualquer repositório GitHub ou derivação Nix).
- **Atalhos Declarativos e Padronizados**:
  - Configure atalhos usando nomes intuitivos (ex: `"Shift+F6"`, `"Home"`, `"Shift+F5"`, `"ScrollLock"`) ou códigos brutos do ReShade.
  - Padrão: **Shift + F6** (Menu do ReShade) e **Shift + F5** (Ligar / Desligar Efeitos).
- **Supressão Automática da Barra de Boas-Vindas**:
  - Patch binário opcional (`disableWelcomeBar = true`) que desativa o tutorial inicial em toda inicialização de jogos.
- **Ferramentas CLI Inclusas**:
  - `reshade-run` / `reshade`: inicializador compatível com Flatpak, Wayland e Steam.
  - `reshade-preset`: consulta e inspeção de presets e perfis por jogo.
  - `reshade-addon`: ativador e desativador de addons opcionais (`.addon64`).
  - `reshade-install-shaders`: sincronizador automático da biblioteca de shaders e texturas.

---

## 🚀 Instalação e Uso com Flakes

Adicione o repositório aos `inputs` do seu `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";

    # nix-reshade-manager
    reshade = {
      url = "github:Cleison-oliveira/nix-reshade-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, reshade, ... }@inputs: {
    # NixOS
    nixosConfigurations.rataria = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        reshade.nixosModules.default
        ./configuration.nix
      ];
    };

    # Home Manager
    homeConfigurations.ratoncio = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        reshade.homeManagerModules.default
        ./home.nix
      ];
    };
  };
}
```

---

## ⚙️ Configuração Declarativa

### 1. Módulo NixOS (`configuration.nix`)

```nix
{ pkgs, ... }: {
  programs.reshade = {
    enable = true;

    # Teclas de atalho (aceita nomes amigáveis como 'Shift+F6', 'Home' ou códigos brutos)
    hotkeys = {
      overlay = "Shift+F6";   # Abrir / Fechar menu ReShade
      effects = "Shift+F5";   # Ativar / Desativar efeitos
    };

    # Desativa barra de tutorial na inicializacao
    disableWelcomeBar = true;

    # Ativar ou desativar colecoes de shaders integradas (com creditos aos respectivos autores)
    builtinPacks = {
      legacy = true;           # Crosire standard shaders (crosire)
      sweetfx = true;          # SweetFX shaders (CeeJay.dk)
      quint = true;            # qUINT framework (Marty McFly / Pascal Gilcher)
      prod80 = true;           # prod80 color grading (prod80)
      otisfx = true;           # OtisFX cinematic shaders (Frans Bouma / Otis_Inf)
      fubax = true;            # Fubax shaders (Fubaxiusz)
      astrayfx = true;         # AstrayFX Clarity.fx (BlueSkyDefender)
      immerse = true;          # iMMERSE Marty's Mods (Marty McFly / Pascal Gilcher)
      gshade = true;           # GShade & PPFX Bloom (Mortalitas)
      reshadeTextures = true;  # Colecao de texturas e LUTs (Bhhl)
      barbatos = true;         # Barbatos XeGTAO & SSR (BarbatosAWLS)
    };

    # Adicionar shader packs customizados declarativamente
    extraPacks = {
      meu-pack-favorito = pkgs.fetchFromGitHub {
        owner = "crosire";
        repo = "reshade-shaders";
        rev = "master";
        hash = "sha256-...";
      };
    };
  };
}
```

### 2. Módulo Home Manager (`home.nix`)

```nix
{ pkgs, ... }: {
  programs.reshade = {
    enable = true;

    hotkeys = {
      overlay = "Shift+F6";
      effects = "Shift+F5";
    };

    # Sincroniza automaticamente a biblioteca de shaders em ~/.local/share/reshade na ativacao
    autoSyncShaders = true;

    # Addons opcionais ativados por padrao
    defaultAddons = [ "fps_limit" ];
  };
}
```

---

## 🎮 Como Usar nos Jogos e Launchers

### Heronite
1. Abra as configurações do jogo no Heronite.
2. Em **Opções de Ambiente (Variáveis)**, adicione:
   - `RESHADE = 1`
3. *(Apenas para jogos 32-bit clássicos como Gears of War 2 ou Spider-Man)*:
   - Habilite a opção **Ativar WoW64** (`enableWoW64 = true`) ou adicione `PROTON_USE_WOW64 = 1`.
4. Inicie o jogo normalmente.

### Heroic Games Launcher
1. Nas configurações do jogo, acesse **Variáveis de Ambiente**.
2. Adicione `RESHADE = 1`.
3. Inicie o jogo.

### Steam
Nas **Opções de Inicialização** do jogo:
```bash
reshade-run %command%
# ou
RESHADE=1 %command%
```

### Flatpak (Jogos e Emuladores)
```bash
reshade-run flatpak run org.ppsspp.PPSSPP
```

### Terminal Direto
```bash
RESHADE=1 vkcube
```

---

## ⌨️ Atalhos Padrão em Jogo

- **Abrir/Fechar Menu do ReShade**: <kbd>Shift</kbd> + <kbd>F6</kbd>
- **Ligar/Desligar Efeitos**: <kbd>Shift</kbd> + <kbd>F5</kbd>

> Todas as alterações visuais, seleção de shaders, ajustes finos e novos presets criados dentro do jogo são salvos e preservados automaticamente em `~/.local/share/reshade/configurations/<jogo>/`.

---

## 🛠️ Comandos Utilitários

```bash
# Iniciar qualquer jogo ou comando com o ReShade ativado
reshade-run meu-jogo

# Iniciar forçando Wine Wayland
reshade-run -w meu-jogo

# Listar e gerenciar presets e pastas de perfis dos jogos instalados
reshade-preset list
reshade-preset dir meu-jogo

# Gerenciar addons opcionais (ex: limitador de FPS)
reshade-addon list
reshade-addon enable fps_limit
reshade-addon disable fps_limit

# Sincronizar ou restaurar a biblioteca de shaders
reshade-install-shaders --sync
reshade-install-shaders --force
```

---

## 🙏 Créditos e Agradecimentos

Este projeto reúne o trabalho extraordinário de desenvolvedores, pesquisadores de computação gráfica e artistas da comunidade open source. Nossos sinceros agradecimentos a todos os autores originais:

### 🧩 Núcleo e Camada Vulkan no Linux

- **ReShade**: Criado e mantido por **Patrick Mours ([crosire](https://github.com/crosire))** e comunidade ReShade ([site oficial](https://reshade.me), [repositório oficial](https://github.com/crosire/reshade)). O injetor pós-processador mais consolidado e versátil para renderização em tempo real.
- **ReShade Linux Vulkan Layer**: Port nativo da camada Vulkan para Linux desenvolvido por **[TheForgotten69](https://github.com/TheForgotten69)** ([repositório](https://github.com/TheForgotten69/reshade)), tornando possível a injeção nativa sem necessidade de modificação nos executáveis dos jogos.
- **nix-reshade**: Empacotamento inicial e inspiração arquitetural para Nix/NixOS por **[LovingMelody](https://github.com/LovingMelody)** ([repositório](https://github.com/LovingMelody/nix-reshade)).

### 🎨 Autores dos Packs de Shaders e Texturas

| Pack | Autor / Criador | Repositório Oficial | Descrição e Efeitos Notáveis |
| :--- | :--- | :--- | :--- |
| **Legacy** | **crosire** (Patrick Mours) & comunidade | [crosire/reshade-shaders](https://github.com/crosire/reshade-shaders) | Repositório oficial e padrão do ReShade. Inclui shaders essenciais de correção, anti-aliasing e utilidades (`FXAA`, `SMAA`, `Curves`, `Tonemap`, `Levels`, `Vibrance`, `LumaSharpen`, `Bloom`). |
| **SweetFX** | **CeeJay.dk** (Christian Cann Schuldt Jensen) | [CeeJayDK/SweetFX](https://github.com/CeeJayDK/SweetFX) | A lendária suíte pioneira que inaugurou e popularizou o universo de pós-processamento em jogos de PC (`HDR`, `Bloom`, `Cineon DPX`, `Technicolor`, `Monochrome`, `Curves`). |
| **qUINT** | **Marty McFly** (Pascal Gilcher) | [martymcmodding/qUINT](https://github.com/martymcmodding/qUINT) | Framework inovador baseado em física e precisão visual (`qUINT_lightroom` estilo Adobe Lightroom, `qUINT_mxao` ambient occlusion, `qUINT_dof`, `qUINT_sharp`, `qUINT_bloom`, `qUINT_ssr`). |
| **prod80** | **prod80** | [prod80/prod80-ReShade-Repository](https://github.com/prod80/prod80-ReShade-Repository) | Suíte avançada de gradação de cores e balanço tonal (`Color Temperature`, `Color Balance`, `CMatrix`, `Film Grain`, `Shadows / Midtones / Highlights`, `Curves`). |
| **OtisFX** | **Frans Bouma** (Otis_Inf) | [FransBouma/OtisFX](https://github.com/FransBouma/OtisFX) | Desenvolvido por especialista em fotografia virtual in-game e ferramentas de câmera (`CinematicDOF`, `AdaptiveFog`, `Emphasize`, `GoldenRatio`, `DepthAlpha`). |
| **Fubax** | **Fubaxiusz** | [Fubaxiusz/fubax-shaders](https://github.com/Fubaxiusz/fubax-shaders) | Efeitos ópticos estilizados de câmera e lente (`Chromatic Aberration`, `PerfectPerspective`, `Prism`, `Fisheye`, `PaintFX`). |
| **AstrayFX** | **BlueSkyDefender** | [BlueSkyDefender/AstrayFX](https://github.com/BlueSkyDefender/AstrayFX) | Shaders com percepção de profundidade de cena, famoso pelo aclamado `Clarity.fx` (aumento de contraste local e nitidez sem estourar cores) e `Depth_Refargo`. |
| **iMMERSE** | **Marty McFly** (Pascal Gilcher) | [martymcmodding/iMMERSE](https://github.com/martymcmodding/iMMERSE) | Suíte contemporânea Marty's Mods com algoritmos de alto desempenho (`MartysMods_SHARPEN`, `MartysMods_SMAA`, `MartysMods_ReGrade`, `LAUNCHPAD`). |
| **GShade & PPFX** | **Mortalitas**, Marot Satil & comunidade | [Mortalitas/GShade-Shaders](https://github.com/Mortalitas/GShade-Shaders) | Coleção consagrada na comunidade de RPGs e MMOs (como Final Fantasy XIV), destacando-se pelo icônico `PPFX_Bloom.fx` e SSAO personalizado. |
| **Barbatos** | **BarbatosAWLS** | [BarbatosAWLS/Reshade-Shaders](https://github.com/BarbatosAWLS/Reshade-Shaders) | Shaders avançados em tempo real com raymarching e computação moderna (`XeGTAO` Intel Ground Truth Ambient Occlusion, `SSR`, `DLAA-T`, `GI` Global Illumination). |
| **Texturas & LUTs** | **Bhhl** (curadoria) | [Bhhl/Reshade-NewFinalRender-textures](https://github.com/Bhhl/Reshade-NewFinalRender-textures) | Pacote consolidado de tabelas de ruído azul (blue noise), máscaras de lente, curvas e mapas LUT indispensáveis para o funcionamento correto dos shaders. |

---

## 📜 Licença

Distribuído sob licença BSD-3-Clause, compatível com o projeto ReShade upstream. Cada pacote de shader mantém sua respectiva licença conforme especificado pelos seus autores em seus repositórios originais.
