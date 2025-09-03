#!/bin/bash
# ===================================================================================
#
#   SCRIPT DE PÓS-INSTALAÇÃO PARA ACER NITRO 5 (AMD+NVIDIA) COM ARCH LINUX + GNOME
#
#   Autor: Lucas A Pereira (aplucas)
#   Refatorado por: Parceiro de Programacao
#   Versão: 9.6 (Refatorada com Ferramentas de IA)
#
#   Este script automatiza a configuração de um ambiente de desenvolvimento completo.
#   - v9.6: Adicionada Etapa 3 para configurar a GPU NVIDIA como primária, garantindo
#           o funcionamento de monitores externos com a ferramenta 'envycontrol'.
#   - v9.5: Adicionada Etapa 21 para instalar ferramentas de IA (Ollama, Stable Diffusion) e drivers CUDA.
#   - v9.4: Corrigida a instalação do XRDP, que está no AUR.
#   - v9.3: Corrigido método de obtenção de IP para usar 'ip addr'.
#
# ===================================================================================

# --- Configuração de Segurança do Script ---
# set -e: Sai imediatamente se um comando (ou pipeline) retornar um status de erro.
# set -u: Trata o uso de variáveis não definidas como um erro, evitando bugs.
# set -o pipefail: Se qualquer comando num pipeline falhar, o status de saída de todo
#                  o pipeline será o do comando que falhou (e não o do último).
set -euo pipefail

# --- Cores para uma melhor visualização ---
C_BLUE="\e[34m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_RESET="\e[0m"

# --- Contadores de Etapas ---
TOTAL_STEPS=22
CURRENT_STEP=1

# ===================================================================================
#                             FUNÇÕES DE AJUDA E UTILITÁRIAS
# ===================================================================================

# --- Funções de Logging ---
info() { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
success() { echo -e "${C_GREEN}[SUCESSO]${C_RESET} $1"; }
warning() { echo -e "${C_YELLOW}[AVISO]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERRO]${C_RESET} $1"; }

section_header() {
    echo -e "\n${C_BLUE}================== [ ETAPA ${CURRENT_STEP}/${TOTAL_STEPS} ] ==================${C_RESET}"
    info "$1"
    ((CURRENT_STEP++))
}

section_header_small() {
    echo -e "\n${C_GREEN}--- $1 ---${C_RESET}"
}

# --- Funções de Verificação ---
is_installed_pacman() { pacman -Q "$1" &>/dev/null; }
is_installed_yay() { yay -Q "$1" &>/dev/null; }
is_installed_flatpak() { flatpak list --app | grep -q "$1"; }
command_exists() { command -v "$1" &>/dev/null; }

# --- Função de Confirmação ---
ask_confirmation() {
    # Se a variável de ambiente YES for 'true', pula a pergunta.
    if [[ "${YES-}" == "true" ]]; then return 0; fi
    read -p "$(echo -e "${C_YELLOW}[PERGUNTA]${C_RESET} $1 [S/n] ")" -n 1 -r REPLY
    echo
    if [[ "$REPLY" =~ ^[Nn]$ ]]; then
        # Retorna 1 se o utilizador disser 'não'
        return 1
    fi
    # Retorna 0 (sucesso) para 'sim' (Enter ou 's'/'S')
    return 0
}

# --- FUNÇÕES DE INSTALAÇÃO GENÉRICAS (A GRANDE MELHORIA!) ---

# Instala pacotes dos repositórios oficiais (pacman)
install_pacman() {
    local pkgs_to_install=()
    for pkg in "$@"; do
        if ! is_installed_pacman "$pkg"; then
            info "A adicionar '$pkg' à lista de instalação do pacman."
            pkgs_to_install+=("$pkg")
        else
            info "Pacote '$pkg' já está instalado (pacman)."
        fi
    done
    if [ ${#pkgs_to_install[@]} -gt 0 ]; then
        info "A instalar pacotes: ${pkgs_to_install[*]}"
        sudo pacman -S --needed --noconfirm "${pkgs_to_install[@]}"
    fi
}

# Instala pacotes do AUR (yay)
install_yay() {
    local pkgs_to_install=()
    for pkg in "$@"; do
        if ! is_installed_yay "$pkg"; then
            info "A adicionar '$pkg' à lista de instalação do AUR."
            pkgs_to_install+=("$pkg")
        else
            info "Pacote '$pkg' já está instalado (AUR)."
        fi
    done
    if [ ${#pkgs_to_install[@]} -gt 0 ]; then
        info "A instalar pacotes do AUR: ${pkgs_to_install[*]}"
        yay -S --needed --noconfirm "${pkgs_to_install[@]}"
    fi
}

# --- FUNÇÃO PARA CARREGAR AMBIENTES ---
source_envs() {
    # NVM (Node.js)
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Rust (Cargo)
    [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
}

# ===================================================================================
#                             FUNÇÕES DE CADA ETAPA
# ===================================================================================

# ETAPA 1: ATUALIZAR O SISTEMA E INSTALAR DEPENDÊNCIAS BÁSICAS
step1_update_system() {
    info "A sincronizar e a atualizar a base de dados de pacotes..."
    sudo pacman -Syu --noconfirm
    local base_deps=(git base-devel curl wget unzip zip jq inetutils)
    info "A verificar dependências essenciais: ${base_deps[*]}"
    install_pacman "${base_deps[@]}"
}

# ETAPA 2: INSTALAR O AUR HELPER (yay)
step2_install_yay() {
    if ! command_exists yay; then
        info "O AUR Helper 'yay' não foi encontrado. A instalar..."
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
        success "'yay' instalado com sucesso."
    else
        info "'yay' já está instalado. A atualizar pacotes do AUR..."
        yay -Syu --noconfirm
    fi
}

# ETAPA 3: CONFIGURAÇÃO DA PLACA GRÁFICA NVIDIA (PARA MONITORES EXTERNOS)
step3_configure_nvidia() {
    if ! ask_confirmation "Desejas configurar a placa NVIDIA como primária para garantir o funcionamento de monitores externos?"; then
        info "A saltar a configuração da GPU NVIDIA. Monitores externos podem não funcionar."
        return
    fi

    section_header_small "A instalar drivers NVIDIA e a ferramenta de gestão 'EnvyControl'"
    # nvidia-dkms é geralmente mais robusto contra atualizações do kernel
    # nvidia-settings é o painel de controlo oficial
    # envycontrol é a ferramenta para alternar os modos
    install_pacman nvidia-dkms nvidia-settings
    install_yay envycontrol

    info "A configurar o sistema para usar o modo 'NVIDIA dedicada'..."
    info "Isto garante a máxima compatibilidade com monitores externos."

    # Verifica o modo atual antes de alternar
    local current_mode
    current_mode=$(sudo envycontrol -q)

    if [[ "$current_mode" == "nvidia" ]]; then
        success "O sistema já está configurado para o modo NVIDIA dedicada."
    else
        info "A mudar para o modo NVIDIA... (Isto pode demorar um momento)"
        sudo envycontrol -s nvidia
        success "Modo NVIDIA configurado com sucesso."
    fi

    warning "É ESSENCIAL reiniciar o computador para que a nova configuração da placa gráfica seja aplicada."
}


# ETAPA 4: INSTALAÇÃO DAS LINGUAGENS DE PROGRAMAÇÃO E FERRAMENTAS
step4_install_langs() {
    if ! ask_confirmation "Desejas instalar Python, Gemini CLI, Node.js (via nvm), Rust e ferramentas, Go e Java?"; then
        info "A saltar a instalação de linguagens de programação."
        return
    fi

    # Python
    install_pacman python python-pip python-virtualenv

    # Node.js (usando NVM)
    if [ ! -d "$HOME/.nvm" ]; then
        info "A instalar Node.js através do NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        source_envs # Carrega o NVM na sessão atual
        nvm install --lts && nvm use --lts && nvm alias default 'lts/*'
    else
        info "NVM já está instalado."
    fi
    source_envs # Garante que está carregado

    # Gemini CLI (via npm)
    if ! command_exists gemini; then
        info "A instalar a ferramenta de linha de comando do Google Gemini..."
        npm install -g @google/gemini-cli
    else
        info "Google Gemini CLI já está instalado."
    fi

    # Rust (usando rustup)
    if [ ! -d "$HOME/.cargo" ]; then
        info "A instalar Rust através do 'rustup'..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    else
        info "Rust (rustup) já está instalado."
    fi
    source_envs # Adiciona o cargo ao PATH da sessão atual

    # Ferramentas Rust
    local rust_tools=(exa bat ytop)
    for tool in "${rust_tools[@]}"; do
        if ! command_exists "$tool"; then
            info "A instalar ferramenta Rust: '$tool'..."
            cargo install "$tool"
        else
            info "Ferramenta Rust '$tool' já está instalada."
        fi
    done

    # Go e Java
    install_pacman go jdk-openjdk
}

# ETAPA 5: FERRAMENTAS DE DESENVOLVIMENTO E PRODUTIVIDADE
step5_install_dev_tools() {
    if ! ask_confirmation "Desejas instalar VS Code, Docker, DBeaver e Insomnia?"; then
        info "A saltar a instalação de ferramentas de desenvolvimento."
        return
    fi
    install_yay visual-studio-code-bin dbeaver insomnia
    # Docker requer passos adicionais
    if ! is_installed_pacman docker; then
        install_pacman docker docker-compose
        info "A ativar e a iniciar o serviço do Docker..."
        sudo systemctl enable --now docker.service
        info "A adicionar o utilizador '$USER' ao grupo do Docker..."
        sudo usermod -aG docker "$USER"
        warning "Para usar o Docker sem 'sudo', precisas de fazer logout e login novamente."
    else
        info "Docker já está instalado."
    fi
}

# ETAPA 6: CONFIGURAÇÃO DO TERMINAL (ZSH + POWERLEVEL10K)
step6_configure_zsh() {
    if ! ask_confirmation "Desejas instalar e configurar o ZSH como terminal padrão?"; then
        info "A saltar a configuração do ZSH."
        return
    fi
    install_pacman zsh zsh-completions
    install_yay ttf-meslo-nerd-font-powerlevel10k

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "A instalar o Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        info "Oh My Zsh já está instalado."
    fi

    # Instala plugins e tema
    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
    [ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM}/themes/powerlevel10k"
    [ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
    [ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"

    info "A garantir que a configuração do .zshrc está correta..."
    tee "$HOME/.zshrc" > /dev/null <<'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load.
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Oh My Zsh plugins.
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Source Oh My Zsh.
source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# --- User customizations ---

# Load NVM (Node Version Manager).
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Add Rust's cargo binary to the PATH.
export PATH="$HOME/.cargo/bin:$PATH"

# Modern command aliases.
alias cat='bat --paging=never'
alias ls='exa --icons'
EOF

    # Altera o shell padrão se necessário
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(which zsh)" ]]; then
        info "A alterar o shell padrão para ZSH para o utilizador $USER..."
        chsh -s "$(which zsh)"
        warning "O teu shell padrão foi alterado para ZSH. A alteração terá efeito no próximo login."
    else
        info "O ZSH já é o shell padrão."
    fi
}


# ETAPA 7: APLICAÇÕES ADICIONAIS
step7_install_extra_apps() {
    if ! ask_confirmation "Desejas instalar LunarVim, Obsidian, RustDesk, FreeTube, Angry IP Scanner, Brave, Chrome, Edge, Teams e JetBrains Toolbox?"; then
        info "A saltar a instalação de aplicações adicionais."
        return
    fi
    install_pacman obsidian
    local aur_apps=(
        lunarvim-git
        rustdesk-bin
        freetube-bin
        ipscan
        brave-bin
        google-chrome
        microsoft-edge-stable-bin
        teams-for-linux
        jetbrains-toolbox
    )
    install_yay "${aur_apps[@]}"
}

# ETAPA 8: INSTALAR APLICAÇÕES VIA FLATPAK (WHATSAPP)
step8_install_flatpak_apps() {
    if ! ask_confirmation "Desejas instalar o WhatsApp for Linux (cliente não-oficial) via Flatpak?"; then
        info "A saltar a instalação de apps via Flatpak."
        return
    fi
    install_pacman flatpak
    local WHATSAPP_ID="com.github.eneshecan.WhatsAppForLinux"
    if ! is_installed_flatpak "$WHATSAPP_ID"; then
        info "A instalar o WhatsApp for Linux via Flatpak..."
        flatpak install --noninteractive --system flathub "$WHATSAPP_ID"
    else
        info "O WhatsApp for Linux já está instalado."
    fi
}

# ETAPA 9: OTIMIZAÇÃO DO SISTEMA E FUNCIONALIDADES DO GNOME
step9_optimize_gnome() {
    if ! ask_confirmation "Desejas instalar ferramentas de gestão, personalização e funcionalidades avançadas do GNOME?"; then
        info "A saltar a otimização do GNOME."
        return
    fi
    # Gestor de energia
    if ! is_installed_pacman power-profiles-daemon; then
        install_pacman power-profiles-daemon
        sudo systemctl enable --now power-profiles-daemon.service
    else
        info "'power-profiles-daemon' já instalado e ativo."
    fi
    # Controlo de ventoinhas
    if ! is_installed_yay nbfc-linux-git; then
        install_yay nbfc-linux-git
        sudo systemctl enable --now nbfc
    else
        info "'nbfc-linux-git' já instalado e ativo."
    fi
    # Ferramentas e extensões
    install_pacman gnome-tweaks gnome-shell-extension-appindicator gnome-network-displays
    local gnome_extensions_aur=(
        gnome-shell-extension-clipboard-history
        gnome-shell-extension-vitals-git
        gnome-shell-extension-pop-shell
        gnome-shell-extension-pip-on-top-git
    )
    install_yay "${gnome_extensions_aur[@]}"
}

# ETAPA 10: INSTALAÇÃO DE CODECS MULTIMÍDIA
step10_install_codecs() {
    if ! ask_confirmation "Desejas instalar os pacotes de codecs essenciais?"; then return; fi
    local codecs=(ffmpeg gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav)
    install_pacman "${codecs[@]}"
}

# ETAPA 11: CONFIGURAÇÃO DO BLUETOOTH
step11_setup_bluetooth() {
    if ! ask_confirmation "Desejas instalar e ativar os serviços de Bluetooth?"; then return; fi
    if ! is_installed_pacman bluez-utils; then
        install_pacman bluez bluez-utils
        sudo systemctl enable --now bluetooth.service
    else
        info "Serviços de Bluetooth já instalados e ativos."
    fi
}

# ETAPA 12: INTEGRAÇÃO COM ANDROID (KDE CONNECT)
step12_setup_kdeconnect() {
    if ! ask_confirmation "Desejas instalar o KDE Connect e a integração GSConnect para o GNOME?"; then return; fi
    install_pacman kdeconnect
    install_yay gnome-shell-extension-gsconnect
}

# ETAPA 13: ATIVAR EXTENSÕES DO GNOME (VERSÃO CORRIGIDA)
step13_enable_gnome_extensions() {
    if ! ask_confirmation "Desejas ativar as extensões do GNOME automaticamente?"; then return; fi
    if ! command_exists gnome-extensions; then
        warning "Comando 'gnome-extensions' não encontrado. Não é possível ativar as extensões."
        return
    fi
    # Mapeamento de nome de pacote para UUID da extensão
    # O UUID pode ser encontrado com `gnome-extensions info <uuid>`
    local -A extensions_map=(
      ["gnome-shell-extension-appindicator"]="appindicatorsupport@rgcjonas.gmail.com"
      ["gnome-shell-extension-clipboard-history"]="clipboard-history@alexsaveau.dev"
      ["gnome-shell-extension-vitals-git"]="Vitals@CoreCoding.com"
      ["gnome-shell-extension-pop-shell"]="pop-shell@system76.com"
      ["gnome-shell-extension-pip-on-top-git"]="pip-on-top@rafostar.github.com"
      ["gnome-shell-extension-gsconnect"]="gsconnect@andyholmes.github.io"
    )
    for pkg_name in "${!extensions_map[@]}"; do
        local uuid="${extensions_map[$pkg_name]}"
        if is_installed_yay "$pkg_name" || is_installed_pacman "$pkg_name"; then
            info "A tentar ativar a extensão: $uuid"
            if gnome-extensions list --enabled | grep -q "$uuid"; then
                info "Extensão '$uuid' já está ativa."
            else
                gnome-extensions enable "$uuid"
                success "Extensão '$uuid' ativada."
            fi
        fi
    done
    warning "Pode ser necessário reiniciar a sessão (logout/login) para que as extensões funcionem corretamente."
}


# Função para adicionar o layout de teclado 'US International' de forma segura.
#
# Esta função verifica se o layout 'us+intl' já existe. Se não existir,
# ela constrói a nova lista de layouts de forma programática para evitar
# erros de formatação e, em seguida, atualiza as configurações do GNOME.
#
step14_setup_keyboard() {
    # Pergunta ao utilizador se deseja continuar. Se a resposta for não, a função termina.
    if ! ask_confirmation "Desejas adicionar o layout 'US International' (americano com ç)?"; then
        return
    fi

    # Obtém a lista atual de layouts de teclado do sistema.
    # O resultado é uma string no formato: [('xkb', 'br'), ('xkb', 'us')]
    local current_layouts
    current_layouts=$(gsettings get org.gnome.desktop.input-sources sources)

    # Verifica se o layout 'us+intl' já está na lista para evitar duplicados.
    # A expressão ' =~ ' faz uma verificação com expressão regular (regex).
    if [[ "$current_layouts" == *"'us+intl'"* ]]; then
        info "Layout 'US International' já está configurado."
    else
        info "Adicionando layout de teclado 'US International'..."
        
        # O novo item que queremos adicionar, já formatado como uma string correta.
        local new_item="('xkb', 'us+intl')"
        local new_layouts

        # Remove o primeiro '[' e o último ']' da string para isolar o conteúdo.
        # Ex: de "[('xkb', 'br')]" para "('xkb', 'br')"
        local content=${current_layouts:1:-1}

        # Verifica se a lista original tinha algum conteúdo.
        if [ -n "$content" ]; then
            # Se a lista não estava vazia, junta o conteúdo antigo com o novo item, separados por vírgula.
            new_layouts="[$content, $new_item]"
        else
            # Se a lista estava vazia, a nova lista contém apenas o novo item.
            new_layouts="[$new_item]"
        fi

        # Define a nova lista de layouts, agora formatada corretamente.
        gsettings set org.gnome.desktop.input-sources sources "$new_layouts"
        success "Layout 'US International' adicionado com sucesso."
    fi
}

# ETAPA 15: CONFIGURAÇÕES DE APLICAÇÕES PADRÃO E GIT
step15_apply_personal_configs() {
    if ! ask_confirmation "Desejas definir o Firefox como navegador padrão, configurar o Git e o VS Code?"; then return; fi
    install_pacman firefox
    if [[ "$(xdg-settings get default-web-browser)" != "firefox.desktop" ]]; then
        info "A definir o Firefox como navegador padrão..."
        xdg-settings set default-web-browser firefox.desktop
    fi
    # Git
    if ! git config --global user.name &>/dev/null; then
        read -p "  -> Insere o teu nome para o Git [Lucas A Pereira]: " git_name
        git config --global user.name "${git_name:-"Lucas A Pereira"}"
    fi
    if ! git config --global user.email &>/dev/null; then
        read -p "  -> Insere o teu email para o Git [l.alexandre100@gmail.com]: " git_email
        git config --global user.email "${git_email:-"l.alexandre100@gmail.com"}"
    fi
    info "Configuração do Git: $(git config --global user.name) <$(git config --global user.email)>"
    # VS Code
    if is_installed_yay visual-studio-code-bin; then
        local vscode_settings_file="$HOME/.config/Code/User/settings.json"
        mkdir -p "$(dirname "$vscode_settings_file")"
        [ ! -f "$vscode_settings_file" ] && echo "{}" > "$vscode_settings_file"
        info "A configurar a fonte e o auto-save no VS Code..."
        local tmp_file
        tmp_file=$(mktemp)
        jq '."editor.fontFamily" = "MesloLGS NF, monospace" | ."terminal.integrated.fontFamily" = "MesloLGS NF, monospace" | ."files.autoSave" = "afterDelay"' \
           "$vscode_settings_file" > "$tmp_file" && mv "$tmp_file" "$vscode_settings_file"
        success "Configurações do VS Code aplicadas."
    fi
}

# ETAPA 16: CONFIGURAÇÃO DE ENERGIA
step16_setup_power_settings() {
    if ! ask_confirmation "Desejas aplicar as configurações de energia recomendadas (sem suspensão, ecrã desliga)?"; then return; fi
    info "A desativar a suspensão automática e a configurar o tempo de ecrã..."
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
    gsettings set org.gnome.desktop.session idle-delay 300 # 5 minutos
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 120 # 2 minutos
}

# ETAPA 17: CONFIGURAÇÃO DE SERVIÇOS DE INÍCIO AUTOMÁTICO
step17_setup_autostart() {
    if is_installed_yay rustdesk-bin && ask_confirmation "Desejas que o RustDesk (acesso remoto) inicie automaticamente com o sistema?"; then
        if ! sudo systemctl is-enabled -q rustdesk.service; then
            info "A ativar o serviço do RustDesk para iniciar com o sistema..."
            sudo systemctl enable rustdesk.service
        else
            info "O serviço do RustDesk já está ativado."
        fi
    fi
}

# Função para criar um perfil otimizado para headsets simples.
create_headset_preset() {
    local config_dir="$HOME/.config/easyeffects/input"
    local config_file="$config_dir/Voz_Adaptada_Headset.json"

    # Apaga qualquer versão antiga deste perfil
    rm -f "$config_file"

    info "Criando o perfil otimizado 'Voz_Adaptada_Headset.json'..."
    mkdir -p "$config_dir"

    # Usando printf com a nova estrutura JSON para headsets.
    printf '%s' '{
    "input": {
        "blocklist": [],
        "plugins_order": [
            "rnnoise#0",
            "filter#0",
            "gate#0",
            "compressor#0"
        ],
        "compressor#0": {
            "attack": 5.0,
            "boost-amount": 6.0,
            "boost-threshold": -72.0,
            "bypass": false,
            "dry": -100.0,
            "hpf-frequency": 100.0,
            "hpf-mode": "12 dB/oct",
            "input-gain": 0.0,
            "knee": 6.0,
            "lpf-frequency": 20000.0,
            "lpf-mode": "off",
            "makeup": 9.0,
            "mode": "Downward",
            "output-gain": 0.0,
            "ratio": 3.0,
            "release": 150.0,
            "release-threshold": -99.9,
            "sidechain": {
                "lookahead": 1.5,
                "mode": "RMS",
                "preamp": 0.0,
                "reactivity": 10.0,
                "source": "Middle",
                "stereo-split-source": "Left/Right",
                "type": "Feed-forward"
            },
            "stereo-split": false,
            "threshold": -24.0,
            "wet": 100.0
        },
        "filter#0": {
            "band#0": {
                "bypass": false,
                "frequency": 150.0,
                "gain": 4.0,
                "mode": "Low Shelf",
                "q": 0.7
            },
            "band#1": {
                "bypass": false,
                "frequency": 1000.0,
                "gain": -2.0,
                "mode": "Bell",
                "q": 0.9
            },
            "band#2": {
                "bypass": false,
                "frequency": 5000.0,
                "gain": 4.0,
                "mode": "High Shelf",
                "q": 0.7
            },
            "bypass": false,
            "input-gain": 0.0,
            "output-gain": 0.0
        },
        "gate#0": {
            "attack": 15.0,
            "bypass": false,
            "curve-threshold": -48.0,
            "curve-zone": -6.0,
            "dry": -100.0,
            "hpf-frequency": 100.0,
            "hpf-mode": "12dB/oct",
            "hysteresis": false,
            "hysteresis-threshold": -12.0,
            "hysteresis-zone": -6.0,
            "input-gain": 0.0,
            "lpf-frequency": 20000.0,
            "lpf-mode": "off",
            "makeup": 0.0,
            "output-gain": 0.0,
            "reduction": -50.0,
            "release": 125.0,
            "sidechain": {
                "input": "Internal",
                "lookahead": 0.0,
                "mode": "RMS",
                "preamp": 0.0,
                "reactivity": 10.0,
                "source": "Middle",
                "stereo-split-source": "Left/Right"
            },
            "stereo-split": false,
            "wet": 100.0
        },
        "rnnoise#0": {
            "bypass": false,
            "enable-vad": true,
            "input-gain": 14.0,
            "model-name": "",
            "output-gain": 0.0,
            "release": 20.01,
            "vad-thres": 75.0,
            "wet": 100.0
        }
    }
}' > "$config_file"

    success "Missão Cumprida! O perfil 'Voz_Adaptada_Headset.json' foi criado."
    info "Para ativá-lo, abra o EasyEffects, vá na aba 'Entrada' e carregue o novo perfil."
}

# ETAPA 18: MELHORAMENTO DE ÁUDIO (EASYEFFECTS)
step18_setup_audio_enhancement() {
    if ! ask_confirmation "Desejas instalar o EasyEffects para melhoramento de áudio?"; then return; fi
    
    install_pacman easyeffects
    install_yay easyeffects-bundy01-presets
    
    warning "O EasyEffects e seus presets foram instalados."

    if ask_confirmation "Desejas criar o perfil de microfone 'Voz Limpa e Sem Ruído'?"; then
        create_headset_preset
        info "Para ativá-lo, abra o EasyEffects, vá na aba 'Entrada' e carregue o perfil."
    fi
}

# ETAPA 19: INSTALAR CLIENTE DE E-MAIL (GEARY)
step19_install_email_client() {
    if ! ask_confirmation "Desejas instalar o Geary, o cliente de e-mail padrão do GNOME?"; then return; fi

    if ! is_installed_pacman geary; then
        info "A instalar o Geary..."
        sudo pacman -S --needed --noconfirm geary
    else
        info "Geary já está instalado."
    fi
}

# ETAPA 20: CONFIGURAÇÕES DO RELÓGIO E CALENDÁRIO DO GNOME
step20_configure_gnome_clock() {
    if ! ask_confirmation "Desejas configurar o relógio para exibir segundos, formato 24h e número da semana?"; then return; fi
    info "A aplicar configurações de relógio e calendário..."
    # Formato de 24 horas
    gsettings set org.gnome.desktop.interface clock-format '24h'
    # Mostrar segundos no relógio
    gsettings set org.gnome.desktop.interface clock-show-seconds true
    # Mostrar número da semana no calendário (quando o relógio é clicado)
    gsettings set org.gnome.desktop.calendar show-weekdate true
    success "Configurações de relógio e calendário aplicadas."
}

# ETAPA 21: CONFIGURAÇÃO DE ACESSO REMOTO COMPLETO
step21_configure_remote_access() {
    if ! ask_confirmation "Desejas configurar o Acesso Remoto (SSH, RDP, Google Remote Desktop e RustDesk)?"; then
        info "A saltar a configuração de acesso remoto."
        return
    fi

    local ip_address
    # Comando robusto para obter o IP, funciona na maioria dos sistemas.
    ip_address=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d'/' -f1 | head -n 1)

    # --- Configuração do SSH (Acesso via Terminal) ---
    section_header_small "A configurar o Servidor SSH"
    info "O SSH permite acesso seguro ao terminal a partir de outra máquina na mesma rede."
    install_pacman openssh
    if ! sudo systemctl is-enabled -q sshd.service; then
        info "A ativar e a iniciar o serviço SSH (sshd.service)..."
        sudo systemctl enable --now sshd.service
        success "Serviço SSH ativado e em execução."
    else
        info "O serviço SSH (sshd) já está ativado."
    fi
    warning "Para te conectares via SSH, usa: ssh ${USER}@${ip_address}"

    # --- Configuração do XRDP (Acesso Gráfico via RDP do Windows) ---
    section_header_small "A configurar o Servidor XRDP para Acesso Remoto do Windows"
    info "O XRDP permite acesso gráfico a partir da mesma rede local."
    # CORREÇÃO: xrdp e xorgxrdp estão no AUR, usar install_yay
    install_yay xrdp xorgxrdp

    local startwm_path="/etc/xrdp/startwm.sh"
    if [ -f "$startwm_path" ]; then
        info "A configurar o XRDP para usar o ambiente de trabalho GNOME..."
        if ! grep -q "GNOME_SHELL_SESSION_MODE" "$startwm_path"; then
            sudo sed -i '/^test -x \/etc\/X11\/Xsession && exec \/etc\/X11\/Xsession/i export XDG_CURRENT_DESKTOP=GNOME\nexport GNOME_SHELL_SESSION_MODE=gnome' "$startwm_path"
            sudo sed -i 's/exec \/etc\/X11\/Xsession/unset DBUS_SESSION_BUS_ADDRESS\n\0/' "$startwm_path"
            success "Configuração do XRDP para GNOME aplicada."
        else
            info "Configuração do XRDP para GNOME já parece estar aplicada."
        fi
    fi

    if ! sudo systemctl is-enabled -q xrdp.service; then
        info "A ativar e a iniciar o serviço XRDP (xrdp.service)..."
        sudo systemctl enable --now xrdp.service
        success "Serviço XRDP ativado e em execução."
    else
        info "O serviço XRDP já está ativado."
    fi
    warning "Para te conectares via RDP, usa o IP: ${ip_address}"

    # --- Configuração do Google Remote Desktop (Acesso de Qualquer Lugar) ---
    section_header_small "A configurar o Google Remote Desktop"
    info "Permite acesso gráfico de qualquer lugar do mundo através da tua conta Google."
    install_yay chrome-remote-desktop

    info "A criar o ficheiro de sessão para o GNOME..."
    local crd_session_file="$HOME/.chrome-remote-desktop-session"
    if [ ! -f "$crd_session_file" ]; then
        echo "exec /usr/lib/gnome-remote-desktop/gnome-remote-desktop --start" > "$crd_session_file"
        success "Ficheiro de sessão do Google Remote Desktop criado."
    else
        info "Ficheiro de sessão do Google Remote Desktop já existe."
    fi
    warning "PASSO FINAL MANUAL NECESSÁRIO para o Google Remote Desktop! Vê as instruções no final do script."

    # --- Verificação do Serviço RustDesk (Acesso Gráfico Alternativo) ---
    section_header_small "A verificar o Serviço RustDesk"
    if is_installed_yay rustdesk-bin; then
        if ! sudo systemctl is-enabled -q rustdesk.service; then
            info "A ativar o serviço do RustDesk para iniciar com o sistema..."
            sudo systemctl enable --now rustdesk.service
            success "Serviço do RustDesk ativado."
        else
            info "O serviço do RustDesk já está ativado."
        fi
    else
        info "RustDesk não está instalado. A saltar a sua configuração de serviço."
    fi
}

# ETAPA 22: FERRAMENTAS DE INTELIGÊNCIA ARTIFICIAL
step22_install_ai_tools() {
    if ! ask_confirmation "Desejas instalar ferramentas de IA (Ollama, Stable Diffusion, Upscayl) e os drivers CUDA da NVIDIA?"; then
        info "A saltar a instalação de ferramentas de IA."
        return
    fi

    # --- Instalação do NVIDIA CUDA Toolkit ---
    section_header_small "A instalar o NVIDIA CUDA Toolkit para aceleração por GPU"
    info "O CUDA é essencial para um bom desempenho em tarefas de IA."
    install_pacman cuda cudnn
    
    # --- Instalação das Aplicações de IA ---
    section_header_small "A instalar as aplicações de IA"
    local ai_apps=(
        ollama
        stable-diffusion-webui-git
        upscayl-bin
    )
    install_yay "${ai_apps[@]}"

    # Ativar o serviço do Ollama
    if sudo systemctl is-enabled -q ollama.service; then
        info "O serviço do Ollama já está ativado."
    else
        info "A ativar o serviço do Ollama para iniciar com o sistema..."
        sudo systemctl enable ollama.service
    fi

    success "Ferramentas de IA e CUDA instalados com sucesso."
    warning "É altamente recomendado reiniciar o computador para que os drivers CUDA sejam totalmente carregados."
}


# ===================================================================================
#                             EXECUÇÃO PRINCIPAL
# ===================================================================================
main() {
    clear
    echo -e "${C_BLUE}===================================================================${C_RESET}"
    echo -e "${C_BLUE}  Bem-vindo ao Script de Pós-Instalação para o Acer Nitro 5    ${C_RESET}"
    echo -e "${C_BLUE}             (Versão Refatorada por Parceiro de Programacao)     ${C_RESET}"
    echo -e "${C_BLUE}===================================================================${C_RESET}"
    echo
    info "Este script irá instalar e configurar o teu ambiente de desenvolvimento."
    echo

    # --- Verificações Iniciais ---
    if [[ $EUID -eq 0 ]]; then
        error "Este script não deve ser executado como root. Use o teu utilizador normal."
        exit 1
    fi

    # Mantém o 'sudo' ativo durante a execução do script.
    info "A pedir permissões de administrador para o restante do script..."
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    if ! ask_confirmation "Desejas iniciar a configuração completa do sistema?"; then
        info "Operação cancelada pelo utilizador. A sair."
        exit 0
    fi

    # --- Execução das Etapas ---
    section_header "A atualizar o sistema e a instalar pacotes essenciais..."
    step1_update_system
    success "Sistema atualizado e pacotes essenciais instalados."

    section_header "A instalar o AUR Helper (yay)..."
    step2_install_yay
    
    section_header "A configurar a Placa Gráfica NVIDIA para monitores externos..."
    step3_configure_nvidia
    success "Configuração da GPU NVIDIA concluída."

    section_header "A instalar ambientes de programação e ferramentas..."
    step4_install_langs
    success "Verificação de ambientes de programação concluída."

    section_header "A instalar ferramentas de desenvolvimento e produtividade..."
    step5_install_dev_tools
    success "Verificação de ferramentas de desenvolvimento concluída."

    section_header "A configurar um terminal moderno (ZSH + Powerlevel10k)..."
    step6_configure_zsh
    success "Terminal configurado com ZSH + Powerlevel10k."

    section_header "A instalar aplicações adicionais..."
    step7_install_extra_apps
    success "Verificação de aplicações adicionais concluída."

    section_header "A instalar aplicações via Flatpak..."
    step8_install_flatpak_apps
    success "Verificação de aplicações Flatpak concluída."

    section_header "A otimizar o sistema e a adicionar funcionalidades ao GNOME..."
    step9_optimize_gnome
    success "Verificação de otimizações do sistema concluída."

    section_header "A instalar codecs para compatibilidade multimídia..."
    step10_install_codecs
    success "Codecs multimídia instalados."

    section_header "A configurar o Bluetooth..."
    step11_setup_bluetooth
    success "Bluetooth configurado e ativado."

    section_header "A configurar a integração com o Android (KDE Connect)..."
    step12_setup_kdeconnect
    success "Integração com Android (KDE Connect) configurada."

    section_header "A ativar as extensões do GNOME instaladas..."
    step13_enable_gnome_extensions
    success "Ativação das extensões do GNOME concluída."

    section_header "A configurar layouts de teclado adicionais..."
    step14_setup_keyboard
    success "Layout de teclado configurado."

    section_header "A aplicar configurações pessoais..."
    step15_apply_personal_configs
    success "Configurações pessoais aplicadas."

    section_header "A configurar a gestão de energia..."
    step16_setup_power_settings
    success "Gestão de energia configurada."

    section_header "A configurar serviços de início automático..."
    step17_setup_autostart
    success "Configuração de serviços de início automático concluída."
    
    section_header "A instalar melhoramentos de áudio (supressão de ruído)..."
    step18_setup_audio_enhancement
    success "Instalação de ferramentas de áudio concluída."

    section_header "A instalar o cliente de e-mail do GNOME..."
    step19_install_email_client
    success "Instalação do cliente de e-mail concluída."

    section_header "A configurar o relógio e o calendário do GNOME..."
    step20_configure_gnome_clock
    success "Configuração do relógio e calendário concluída."

    section_header "A configurar o Acesso Remoto Completo..."
    step21_configure_remote_access
    success "Configuração de Acesso Remoto concluída."

    section_header "A instalar Ferramentas de Inteligência Artificial..."
    step22_install_ai_tools
    success "Instalação de Ferramentas de IA concluída."

    # --- Mensagem Final ---
    echo
    echo -e "${C_GREEN}===================================================================${C_RESET}"
    echo -e "${C_GREEN}      SETUP CONCLUÍDO COM SUCESSO!                                 ${C_RESET}"
    echo -e "${C_GREEN}===================================================================${C_RESET}"
    echo
    info "Resumo e Próximos Passos:"
    echo -e "1.  ${C_RED}REINICIA O TEU COMPUTADOR AGORA${C_RESET} para aplicar todas as alterações."
    echo "    - Após o reinício, a placa gráfica NVIDIA estará ativa, e os monitores externos funcionarão."
    echo
    echo -e "2.  ${C_YELLOW}Opções de Acesso Remoto:${C_RESET}"
    local ip_address
    ip_address=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d'/' -f1 | head -n 1)
    echo "    - O teu endereço de IP local é: ${C_GREEN}${ip_address}${C_RESET}"
    echo "    - ${C_GREEN}Acesso via Terminal (SSH):${C_RESET} Em outra máquina na mesma rede, usa: ${C_GREEN}ssh ${USER}@${ip_address}${C_RESET}"
    echo "    - ${C_GREEN}Acesso Gráfico na Rede Local (RDP):${C_RESET} No Windows, abre a 'Conexão de Área de Trabalho Remota' e insere o IP ${C_GREEN}${ip_address}${C_RESET}."
    echo
    echo -e "3.  ${C_YELLOW}CONFIGURAÇÃO FINAL - Google Remote Desktop (Acesso de Qualquer Lugar):${C_RESET}"
    echo "    - Este passo é ${C_RED}MANUAL${C_RESET} e precisa ser feito para ativar o acesso."
    echo "    1. Num navegador, acede a: ${C_GREEN}https://remotedesktop.google.com/headless${C_RESET}"
    echo "    2. Faz login com a tua conta Google e segue os passos para autorizar um novo computador."
    echo "    3. ${C_RED}COPIA${C_RESET} o comando gerado pela página, ${C_RED}COLA${C_RESET} no teu terminal e executa."
    echo "    4. Define um PIN de 6 dígitos. Esse será o teu PIN de acesso."
    echo "    - Feito! O teu computador aparecerá em ${C_GREEN}https://remotedesktop.google.com${C_RESET}"
    echo
    echo -e "4.  ${C_YELLOW}A usar as tuas novas Ferramentas de IA:${C_RESET}"
    echo "    - ${C_GREEN}Ollama (Modelos de Linguagem):${C_RESET} Abre um terminal e executa um modelo. Exemplo:"
    echo "      ${C_BLUE}ollama run llama3${C_RESET}"
    echo "    - ${C_GREEN}Stable Diffusion (Gerador de Imagens):${C_RESET} Procura por 'Stable Diffusion WebUI' no teu menu de aplicações para iniciar a interface web."
    echo "    - ${C_GREEN}Upscayl (Melhorar Imagens):${C_RESET} Procura por 'Upscayl' no teu menu de aplicações e arrasta as tuas imagens para lá."
    echo
    echo -e "5.  ${C_YELLOW}Primeiro Login com o Novo Terminal:${C_RESET}"
    echo "    - O assistente do ${C_GREEN}Powerlevel10k${C_RESET} pode iniciar. Se não, executa: ${C_GREEN}p10k configure${C_RESET}"
    echo
    success "Aproveita o teu novo ambiente de desenvolvimento e IA no Arch Linux!"
}

# --- Ponto de Entrada do Script ---
# Chama a função principal para iniciar a execução, passando todos os- argumentos
# que o script possa ter recebido (útil para testes futuros).
main "$@"
