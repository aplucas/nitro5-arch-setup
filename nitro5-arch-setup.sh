#!/bin/bash
# ===================================================================================
#
#   SCRIPT DE PÓS-INSTALAÇÃO PARA ACER NITRO 5 (AMD+NVIDIA) COM ARCH LINUX + GNOME
#
#   Autor: Lucas A Pereira (aplucas)
#   Refatorado por: Parceiro de Programacao
#   Versão: 8.5 (Refatorada)
#
#   Este script automatiza a configuração de um ambiente de desenvolvimento completo.
#   - v8.5: Refatoração para eliminar código repetido e melhorar a manutenibilidade
#           usando funções de instalação genéricas e listas de pacotes em arrays.
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
TOTAL_STEPS=18
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
    local base_deps=(git base-devel curl wget unzip zip jq)
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

# ETAPA 3: INSTALAÇÃO DAS LINGUAGENS DE PROGRAMAÇÃO E FERRAMENTAS
step3_install_langs() {
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

# ETAPA 4: FERRAMENTAS DE DESENVOLVIMENTO E PRODUTIVIDADE
step4_install_dev_tools() {
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

# ETAPA 5: CONFIGURAÇÃO DO TERMINAL (ZSH + POWERLEVEL10K)
step5_configure_zsh() {
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


# ETAPA 6: APLICAÇÕES ADICIONAIS
step6_install_extra_apps() {
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

# ETAPA 7: INSTALAR APLICAÇÕES VIA FLATPAK (WHATSAPP)
step7_install_flatpak_apps() {
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

# ETAPA 8: OTIMIZAÇÃO DO SISTEMA E FUNCIONALIDADES DO GNOME
step8_optimize_gnome() {
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

# ETAPA 9: INSTALAÇÃO DE CODECS MULTIMÍDIA
step9_install_codecs() {
    if ! ask_confirmation "Desejas instalar os pacotes de codecs essenciais?"; then return; fi
    local codecs=(ffmpeg gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav)
    install_pacman "${codecs[@]}"
}

# ETAPA 10: CONFIGURAÇÃO DO BLUETOOTH
step10_setup_bluetooth() {
    if ! ask_confirmation "Desejas instalar e ativar os serviços de Bluetooth?"; then return; fi
    if ! is_installed_pacman bluez-utils; then
        install_pacman bluez bluez-utils
        sudo systemctl enable --now bluetooth.service
    else
        info "Serviços de Bluetooth já instalados e ativos."
    fi
}

# ETAPA 11: INTEGRAÇÃO COM ANDROID (KDE CONNECT)
step11_setup_kdeconnect() {
    if ! ask_confirmation "Desejas instalar o KDE Connect e a integração GSConnect para o GNOME?"; then return; fi
    install_pacman kdeconnect
    install_yay gnome-shell-extension-gsconnect
}

# ETAPA 12: ATIVAR EXTENSÕES DO GNOME (VERSÃO CORRIGIDA)
step12_enable_gnome_extensions() {
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
step13_setup_keyboard() {
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

# ETAPA 14: CONFIGURAÇÕES DE APLICAÇÕES PADRÃO E GIT
step14_apply_personal_configs() {
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

# ETAPA 15: CONFIGURAÇÃO DE ENERGIA
step15_setup_power_settings() {
    if ! ask_confirmation "Desejas aplicar as configurações de energia recomendadas (sem suspensão, ecrã desliga)?"; then return; fi
    info "A desativar a suspensão automática e a configurar o tempo de ecrã..."
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
    gsettings set org.gnome.desktop.session idle-delay 300 # 5 minutos
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 120 # 2 minutos
}

# ETAPA 16: CONFIGURAÇÃO DE SERVIÇOS DE INÍCIO AUTOMÁTICO
step16_setup_autostart() {
    if is_installed_yay rustdesk-bin && ask_confirmation "Desejas que o RustDesk (acesso remoto) inicie automaticamente com o sistema?"; then
        if ! sudo systemctl is-enabled -q rustdesk.service; then
            info "A ativar o serviço do RustDesk para iniciar com o sistema..."
            sudo systemctl enable rustdesk.service
        else
            info "O serviço do RustDesk já está ativado."
        fi
    fi
}

# Função idempotente para criar um perfil de microfone padrão
create_microphone_preset() {
    local config_dir="$HOME/.config/easyeffects/input"
    local config_file="$config_dir/Voz_Limpa_e_Sem_Ruido.json"

    if [ -f "$config_file" ]; then
        info "O perfil de microfone '$config_file' já existe."
        info "Nenhuma alteração foi feita para preservar suas configurações."
        return 0
    fi

    info "Criando o perfil de microfone 'Voz_Limpa_e_Sem_Ruido.json'..."
    mkdir -p "$config_dir"

    cat << EOF > "$config_file"
{
    "bypass": false,
    "plugins_order": [
        "rnnoise_0",
        "gate_0",
        "compressor_0"
    ],
    "rnnoise_0": {
        "bypass": false,
        "input_gain": 10.0,
        "output_gain": 10.0,
        "model": "shannon_human-large-2023-01-23",
        "vad_threshold": 90.0
    },
    "gate_0": {
        "attack": 25.0,
        "bypass": false,
        "hold": 150.0,
        "hysteresis": 4.0,
        "input_gain": 0.0,
        "lookahead": 1.5,
        "output_gain": 0.0,
        "range": 60.0,
        "ratio": 2.0,
        "release": 250.0,
        "sidechain_source": "Middle",
        "threshold": -42.0
    },
    "compressor_0": {
        "attack": 5.0,
        "bypass": false,
        "input_gain": 0.0,
        "knee": 6.0,
        "makeup": 6.0,
        "output_gain": 0.0,
        "ratio": 4.0,
        "release": 100.0,
        "sidechain_source": "Middle",
        "threshold": -20.0
    }
}
EOF
    success "Perfil 'Voz Limpa e Sem Ruído.json' criado com sucesso!"
}


# ETAPA 17: MELHORAMENTO DE ÁUDIO (EASYEFFECTS)
step17_setup_audio_enhancement() {
    if ! ask_confirmation "Desejas instalar o EasyEffects para melhoramento de áudio (supressão de ruído)?"; then return; fi
    
    # Instala o EasyEffects dos repositórios oficiais
    install_pacman easyeffects
    
    # Instala os presets da comunidade encontrados no AUR
    install_yay easyeffects-bundy01-presets
    
    warning "O EasyEffects e seus presets foram instalados."

    # Pergunta se o usuário deseja aplicar a configuração de microfone
    if ask_confirmation "Desejas criar um perfil padrão de microfone para ter uma 'Voz Limpa e Sem Ruído'?"; then
        create_microphone_preset
        success "Perfil 'Voz Limpa e Sem Ruído.json' criado com sucesso!"
        info "Para ativá-lo, siga os passos abaixo:"
        echo "1. Abra o aplicativo 'EasyEffects'."
        echo "2. Na aba 'Entrada', selecione o seu microfone."
        echo "3. No painel 'Presets' à direita, clique em 'Carregar'."
        echo "4. Selecione o perfil 'Voz Limpa e Sem Ruído' e aproveite!"
    else
        warning "Ok. A configuração do EasyEffects deverá ser feita manualmente através da aplicação."
    fi
}

# ETAPA 18: INSTALAR CLIENTE DE E-MAIL (GEARY)
step18_install_email_client() {
    ask_confirmation "Desejas instalar o Geary, o cliente de e-mail padrão do GNOME?"

    if ! is_installed_pacman geary; then
        info "A instalar o Geary..."
        sudo pacman -S --needed --noconfirm geary
    else
        info "Geary já está instalado."
    fi
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

    section_header "A instalar ambientes de programação e ferramentas..."
    step3_install_langs
    success "Verificação de ambientes de programação concluída."

    section_header "A instalar ferramentas de desenvolvimento e produtividade..."
    step4_install_dev_tools
    success "Verificação de ferramentas de desenvolvimento concluída."

    section_header "A configurar um terminal moderno (ZSH + Powerlevel10k)..."
    step5_configure_zsh
    success "Terminal configurado com ZSH + Powerlevel10k."

    section_header "A instalar aplicações adicionais..."
    step6_install_extra_apps
    success "Verificação de aplicações adicionais concluída."

    section_header "A instalar aplicações via Flatpak..."
    step7_install_flatpak_apps
    success "Verificação de aplicações Flatpak concluída."

    section_header "A otimizar o sistema e a adicionar funcionalidades ao GNOME..."
    step8_optimize_gnome
    success "Verificação de otimizações do sistema concluída."

    section_header "A instalar codecs para compatibilidade multimídia..."
    step9_install_codecs
    success "Codecs multimídia instalados."

    section_header "A configurar o Bluetooth..."
    step10_setup_bluetooth
    success "Bluetooth configurado e ativado."

    section_header "A configurar a integração com o Android (KDE Connect)..."
    step11_setup_kdeconnect
    success "Integração com Android (KDE Connect) configurada."

    section_header "A ativar as extensões do GNOME instaladas..."
    step12_enable_gnome_extensions
    success "Ativação das extensões do GNOME concluída."

    section_header "A configurar layouts de teclado adicionais..."
    step13_setup_keyboard
    success "Layout de teclado configurado."

    section_header "A aplicar configurações pessoais..."
    step14_apply_personal_configs
    success "Configurações pessoais aplicadas."

    section_header "A configurar a gestão de energia..."
    step15_setup_power_settings
    success "Gestão de energia configurada."

    section_header "A configurar serviços de início automático..."
    step16_setup_autostart
    success "Configuração de serviços de início automático concluída."
    
    section_header "A instalar melhoramentos de áudio (supressão de ruído)..."
    step17_setup_audio_enhancement
    success "Instalação de ferramentas de áudio concluída."

    section_header "A instalar o cliente de e-mail do GNOME..."
    step18_install_email_client
    success "Instalação do cliente de e-mail concluída."

    # --- Mensagem Final ---
    # A sua mensagem final já era excelente, mantive-a na íntegra.
    echo
    echo -e "${C_GREEN}===================================================================${C_RESET}"
    echo -e "${C_GREEN}      SETUP CONCLUÍDO COM SUCESSO!                                 ${C_RESET}"
    echo -e "${C_GREEN}===================================================================${C_RESET}"
    echo
    info "Resumo e Próximos Passos:"
    echo -e "1.  ${C_RED}REINICIA O TEU COMPUTADOR AGORA${C_RESET} para aplicar todas as alterações."
    echo "    - Após o reinício, o novo shell e as extensões do GNOME estarão a funcionar."
    echo
    echo -e "2.  ${C_YELLOW}Funcionalidades Avançadas:${C_RESET}"
    echo "    - ${C_GREEN}Tiling de Janelas:${C_RESET} Procura um novo ícone na barra superior para ativar/desativar o tiling."
    echo "    - ${C_GREEN}Picture-in-Picture:${C_RESET} Procura pelo ícone de PiP em vídeos (ex: no YouTube no Firefox)."
    echo "    - ${C_GREEN}Espelhamento de Ecrã:${C_RESET} Abre as 'Definições' > 'Ecrãs' e procura a opção para te conectares a um ecrã sem fios."
    echo
    echo -e "3.  ${C_YELLOW}Conectar com o Android:${C_RESET}"
    echo "    - Instala a app 'KDE Connect' no teu Android a partir da Play Store."
    echo "    - Certifica-te que ambos os dispositivos estão na mesma rede Wi-Fi e emparelha-os."
    echo
    echo -e "4.  ${C_YELLOW}Primeiro Login com o Novo Terminal:${C_RESET}"
    echo "    - Os teus comandos 'ls' e 'cat' agora usarão 'exa' e 'bat' automaticamente."
    echo "    - O assistente do ${C_GREEN}Powerlevel10k${C_RESET} pode iniciar. Se não, executa: ${C_GREEN}p10k configure${C_RESET}"
    echo
    echo -e "5.  ${C_YELLOW}Layout de Teclado:${C_RESET}"
    echo "    - O layout 'US International' foi adicionado. Pressiona ${C_GREEN}Super + Espaço${C_RESET} para alternar entre os layouts."
    echo
    echo -e "6.  ${C_YELLOW}Google Gemini CLI:${C_RESET}"
    echo "    - Para usares a CLI do Gemini, primeiro precisas de a configurar com a tua API Key."
    echo "    - Executa no terminal: ${C_GREEN}gemini init${C_RESET} e segue as instruções."
    echo
    echo -e "7.  ${C_YELLOW}Melhorar o teu Microfone (Supressão de Ruído):${C_RESET}"
    echo "    - Instalamos o ${C_GREEN}EasyEffects${C_RESET}, uma poderosa ferramenta de áudio."
    echo "    - Para ativar a supressão de ruído, segue estes passos após o reinício:"
    echo "      1. Abre a aplicação 'EasyEffects'."
    echo "      2. No painel esquerdo, clica no separador 'Entrada' (ícone de microfone)."
    echo "      3. No painel direito, clica em 'Efeitos' > '+ Adicionar Efeito'."
    echo "      4. Procura e adiciona o efeito ${C_GREEN}'Redução de Ruído'${C_RESET}."
    echo "      5. Para resultados excelentes, seleciona o motor ${C_GREEN}'RNNoise'${C_RESET} dentro do efeito."
    echo "      6. Ativa os efeitos no interruptor geral no canto superior esquerdo da janela."
    echo "    - Para que os efeitos iniciem com o sistema, vai às preferências do EasyEffects e ativa a opção 'Iniciar Serviço no Login'."
    echo
    echo -e "8.  ${C_YELLOW}Configurar o teu E-mail:${C_RESET}"
    echo "    - Instalamos o ${C_GREEN}Geary${C_RESET}, o cliente de e-mail oficial do GNOME."
    echo "    - Para uma integração perfeita, vai a 'Definições' > 'Contas Online' e adiciona a tua conta Google, Microsoft, etc."
    echo "    - Ao abrires o Geary, ele deverá detetar e configurar a tua conta automaticamente."
    echo
    success "Aproveita o teu novo ambiente de desenvolvimento no Arch Linux!"
}

# --- Ponto de Entrada do Script ---
# Chama a função principal para iniciar a execução, passando todos os argumentos
# que o script possa ter recebido (útil para testes futuros).
main "$@"