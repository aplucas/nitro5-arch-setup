#!/bin/bash
# ===================================================================================
#
#   SCRIPT DE PÓS-INSTALAÇÃO PARA ACER NITRO 5 (AMD+NVIDIA) COM ARCH LINUX + GNOME
#
#   Autor: Lucas A Pereira (aplucas)
#   Refatorado por: Parceiro de Programacao
#   Versão: 8.2 (Refatorada)
#
#   Este script automatiza a configuração de um ambiente de desenvolvimento completo.
#   - v8.2: Adicionada a dependência 'zip' para corrigir a compilação de extensões.
#   - v8.1: Corrigido o ID do Flatpak do WhatsApp.
#   - v8.0: Refatorado para maior modularidade e manutenibilidade.
#
# ===================================================================================

# --- Configuração de Segurança do Script ---
# set -e: Sai imediatamente se um comando falhar.
# set -u: Trata variáveis não definidas como um erro.
# set -o pipefail: O status de saída de um pipeline é o do último comando que falhou.
set -euo pipefail

# --- Cores para uma melhor visualização ---
C_BLUE="\e[34m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_RESET="\e[0m"

# --- Contadores de Etapas ---
TOTAL_STEPS=16
CURRENT_STEP=1

# --- Funções de Ajuda ---
info() {
    echo -e "${C_BLUE}[INFO]${C_RESET} $1"
}

success() {
    echo -e "${C_GREEN}[SUCESSO]${C_RESET} $1"
}

warning() {
    echo -e "${C_YELLOW}[AVISO]${C_RESET} $1"
}

error() {
    echo -e "${C_RED}[ERRO]${C_RESET} $1"
}

section_header() {
    echo -e "\n${C_BLUE}================== [ ETAPA ${CURRENT_STEP}/${TOTAL_STEPS} ] ==================${C_RESET}"
    info "$1"
    ((CURRENT_STEP++))
}

# Verifica se um pacote está instalado via pacman (oficial)
is_installed_pacman() {
    pacman -Q "$1" &> /dev/null
}

# Verifica se um pacote está instalado via yay (AUR)
is_installed_yay() {
    yay -Q "$1" &> /dev/null
}

# Verifica se uma aplicação está instalada via flatpak
is_installed_flatpak() {
    flatpak list --app | grep -q "$1"
}

ask_confirmation() {
    # Se a variável de ambiente YES for 'true', pula a pergunta.
    if [[ "${YES-}" == "true" ]]; then
        return 0
    fi
    read -p "$(echo -e "${C_YELLOW}[PERGUNTA]${C_RESET} $1 [S/n] ")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ && $REPLY != "" ]]; then
        error "Operação cancelada pelo utilizador."
        exit 1
    fi
}

# ===================================================================================
#                             FUNÇÕES DE CADA ETAPA
# ===================================================================================

# ETAPA 1: ATUALIZAR O SISTEMA E INSTALAR DEPENDÊNCIAS BÁSICAS
step1_update_system() {
    sudo pacman -Syu --noconfirm
    sudo pacman -S --needed --noconfirm git base-devel curl wget unzip zip jq
}

# ETAPA 2: INSTALAR O AUR HELPER (yay)
step2_install_yay() {
    if ! command -v yay &> /dev/null; then
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
    ask_confirmation "Desejas instalar Python, Gemini CLI, Node.js (via nvm), Rust (com exa, bat, ytop), Go e Java?"

    # Python
    if ! is_installed_pacman python; then sudo pacman -S --needed --noconfirm python python-pip python-virtualenv; else info "Python já instalado."; fi

    # Node.js (usando NVM)
    if [ ! -d "$HOME/.nvm" ]; then
        info "A instalar Node.js através do NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
        nvm use --lts
        nvm alias default 'lts/*'
    else
        info "NVM já está instalado."
    fi
    # Carrega o NVM na sessão atual
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Gemini CLI (via npm)
    info "A instalar a ferramenta de linha de comando do Google Gemini..."
    if ! command -v gemini &> /dev/null; then npm install -g @google/gemini-cli; else info "Google Gemini CLI já está instalado."; fi

    # Rust (usando rustup)
    if [ ! -d "$HOME/.cargo" ]; then
        info "A instalar Rust através do 'rustup'..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    else
        info "Rust (rustup) já está instalado."
    fi
    # Adiciona o cargo ao PATH da sessão atual
    source "$HOME/.cargo/env"

    # Ferramentas Rust
    if ! command -v exa &> /dev/null; then cargo install exa; else info "'exa' já está instalado."; fi
    if ! command -v bat &> /dev/null; then cargo install bat; else info "'bat' já está instalado."; fi
    if ! command -v ytop &> /dev/null; then cargo install ytop; else info "'ytop' já está instalado."; fi

    # Go e Java
    if ! is_installed_pacman go; then sudo pacman -S --needed --noconfirm go; else info "Go já instalado."; fi
    if ! is_installed_pacman jdk-openjdk; then sudo pacman -S --needed --noconfirm jdk-openjdk; else info "Java (OpenJDK) já instalado."; fi
}

# ETAPA 4: FERRAMENTAS DE DESENVOLVIMENTO E PRODUTIVIDADE
step4_install_dev_tools() {
    ask_confirmation "Desejas instalar VS Code, Docker, DBeaver e Insomnia?"
    if ! is_installed_yay visual-studio-code-bin; then yay -S --needed --noconfirm visual-studio-code-bin; else info "VS Code já instalado."; fi
    if ! is_installed_pacman docker; then
        sudo pacman -S --needed --noconfirm docker docker-compose
        sudo systemctl enable --now docker.service
        sudo usermod -aG docker "$USER"
        warning "Para usar o Docker sem 'sudo', precisas de fazer logout e login novamente."
    else
        info "Docker já instalado."
    fi
    if ! is_installed_yay dbeaver; then yay -S --needed --noconfirm dbeaver; else info "DBeaver já instalado."; fi
    if ! is_installed_yay insomnia; then yay -S --needed --noconfirm insomnia; else info "Insomnia já instalado."; fi
}

# ETAPA 5: CONFIGURAÇÃO DO TERMINAL (ZSH + POWERLEVEL10K)
step5_configure_zsh() {
    ask_confirmation "Desejas instalar e configurar o ZSH como terminal padrão?"
    if ! is_installed_pacman zsh; then sudo pacman -S --needed --noconfirm zsh zsh-completions; else info "ZSH já instalado."; fi
    if ! is_installed_yay ttf-meslo-nerd-font-powerlevel10k; then yay -S --needed --noconfirm ttf-meslo-nerd-font-powerlevel10k; else info "Fonte Meslo Nerd já instalada."; fi

    if [ ! -d "$HOME/.oh-my-zsh" ]; then sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; fi

    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
    if [ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ]; then git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM}/themes/powerlevel10k"; fi
    if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]; then git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"; fi
    if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]; then git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"; fi

    info "A garantir que a configuração do .zshrc está correta..."
    tee "$HOME/.zshrc" > /dev/null <<'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Oh My Zsh plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Source Oh My Zsh
source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# --- Customizações do Utilizador ---

# Adiciona o binário do Cargo (Rust) ao PATH
export PATH="$HOME/.cargo/bin:$PATH"

# NVM (Node.js) configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Aliases para comandos modernos
alias cat='bat --paging=never'
alias ls='exa --icons'
EOF

    # Altera o shell padrão se necessário
    CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
    ZSH_PATH=$(which zsh)
    if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
        info "A alterar o shell padrão para ZSH..."
        chsh -s "$ZSH_PATH"
        warning "O teu shell padrão foi alterado para ZSH. A alteração terá efeito no próximo login."
    else
        info "O ZSH já é o shell padrão."
    fi
}

# ETAPA 6: APLICAÇÕES ADICIONAIS
step6_install_extra_apps() {
    ask_confirmation "Desejas instalar LunarVim, Obsidian, RustDesk, FreeTube, Angry IP Scanner, Brave, Chrome, Edge, Teams e JetBrains Toolbox?"
    if ! is_installed_yay lunarvim-git; then yay -S --needed --noconfirm lunarvim-git; else info "LunarVim já instalado."; fi
    if ! is_installed_pacman obsidian; then sudo pacman -S --needed --noconfirm obsidian; else info "Obsidian já instalado."; fi
    if ! is_installed_yay rustdesk-bin; then yay -S --needed --noconfirm rustdesk-bin; else info "RustDesk já instalado."; fi
    if ! is_installed_yay freetube-bin; then yay -S --needed --noconfirm freetube-bin; else info "FreeTube já instalado."; fi
    if ! is_installed_yay ipscan; then yay -S --needed --noconfirm ipscan; else info "Angry IP Scanner já instalado."; fi
    if ! is_installed_yay brave-bin; then yay -S --needed --noconfirm brave-bin; else info "Brave Browser já instalado."; fi
    if ! is_installed_yay google-chrome; then yay -S --needed --noconfirm google-chrome; else info "Google Chrome já instalado."; fi
    if ! is_installed_yay microsoft-edge-stable-bin; then yay -S --needed --noconfirm microsoft-edge-stable-bin; else info "Microsoft Edge já instalado."; fi
    if ! is_installed_yay teams-for-linux; then yay -S --needed --noconfirm teams-for-linux; else info "Microsoft Teams já instalado."; fi
    if ! is_installed_yay jetbrains-toolbox; then yay -S --needed --noconfirm jetbrains-toolbox; else info "JetBrains Toolbox já instalado."; fi
}

# ETAPA 7: INSTALAR APLICAÇÕES VIA FLATPAK (WHATSAPP)
step7_install_flatpak_apps() {
    ask_confirmation "Desejas instalar o WhatsApp for Linux (cliente não-oficial) via Flatpak?"
    local WHATSAPP_ID="com.github.eneshecan.WhatsAppForLinux"

    if ! is_installed_pacman flatpak; then
        info "A instalar o Flatpak..."
        sudo pacman -S --needed --noconfirm flatpak
    else
        info "O Flatpak já está instalado."
    fi

    if ! is_installed_flatpak "$WHATSAPP_ID"; then
        info "A instalar o WhatsApp for Linux via Flatpak..."
        sudo flatpak install --noninteractive --system flathub "$WHATSAPP_ID"
    else
        info "O WhatsApp for Linux já está instalado."
    fi
}

# ETAPA 8: OTIMIZAÇÃO DO SISTEMA E FUNCIONALIDADES DO GNOME
step8_optimize_gnome() {
    ask_confirmation "Desejas instalar ferramentas de gestão, personalização e funcionalidades avançadas do GNOME?"
    # Gestor de energia padrão
    if ! is_installed_pacman power-profiles-daemon; then
        sudo pacman -S --needed --noconfirm power-profiles-daemon
        sudo systemctl enable --now power-profiles-daemon.service
    else
        info "'power-profiles-daemon' já instalado e ativo."
    fi
    # Controlo de ventoinhas
    if ! is_installed_yay nbfc-linux-git; then
        yay -S --needed --noconfirm nbfc-linux-git
        sudo systemctl enable --now nbfc
    else
        info "'nbfc-linux-git' já instalado e ativo."
    fi
    # Ferramentas e extensões
    if ! is_installed_pacman gnome-tweaks; then sudo pacman -S --needed --noconfirm gnome-tweaks; else info "GNOME Tweaks já instalado."; fi
    if ! is_installed_pacman gnome-shell-extension-appindicator; then sudo pacman -S --needed --noconfirm gnome-shell-extension-appindicator; else info "Extensão AppIndicator já instalada."; fi
    if ! is_installed_yay gnome-shell-extension-clipboard-history; then yay -S --needed --noconfirm gnome-shell-extension-clipboard-history; else info "Extensão Clipboard History já instalada."; fi
    if ! is_installed_yay gnome-shell-extension-vitals-git; then yay -S --needed --noconfirm gnome-shell-extension-vitals-git; else info "Extensão Vitals já instalada."; fi
    if ! is_installed_yay gnome-shell-extension-pop-shell; then yay -S --needed --noconfirm gnome-shell-extension-pop-shell; else info "Extensão Pop Shell já instalada."; fi
    if ! is_installed_yay gnome-shell-extension-pip-on-top-git; then yay -S --needed --noconfirm gnome-shell-extension-pip-on-top-git; else info "Extensão Picture-in-Picture já instalada."; fi
    if ! is_installed_yay gnome-network-displays; then yay -S --needed --noconfirm gnome-network-displays; else info "Ferramenta Network Displays já instalada."; fi
}

# ETAPA 9: INSTALAÇÃO DE CODECS MULTIMÍDIA
step9_install_codecs() {
    ask_confirmation "Desejas instalar os pacotes de codecs essenciais (ffmpeg, gstreamer)?"
    sudo pacman -S --needed --noconfirm ffmpeg gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
}

# ETAPA 10: CONFIGURAÇÃO DO BLUETOOTH
step10_setup_bluetooth() {
    ask_confirmation "Desejas instalar e ativar os serviços de Bluetooth?"
    if ! is_installed_pacman bluez-utils; then
        sudo pacman -S --needed --noconfirm bluez bluez-utils
        sudo systemctl enable --now bluetooth.service
    else
        info "Serviços de Bluetooth já instalados e ativos."
    fi
}

# ETAPA 11: INTEGRAÇÃO COM ANDROID (KDE CONNECT)
step11_setup_kdeconnect() {
    ask_confirmation "Desejas instalar o KDE Connect e a integração GSConnect para o GNOME?"
    if ! is_installed_pacman kdeconnect; then sudo pacman -S --needed --noconfirm kdeconnect; else info "KDE Connect já instalado."; fi
    if ! is_installed_yay gnome-shell-extension-gsconnect; then yay -S --needed --noconfirm gnome-shell-extension-gsconnect; else info "Extensão GSConnect já instalada."; fi
}

# ETAPA 12: ATIVAR EXTENSÕES DO GNOME
step12_enable_gnome_extensions() {
    ask_confirmation "Desejas ativar as extensões do GNOME automaticamente?"
    EXTENSIONS_TO_ENABLE=(
        "appindicatorsupport@rgcjonas.gmail.com"
        "clipboard-history@alexsaveau.dev"
        "Vitals@CoreCoding.com"
        "pop-shell@system76.com"
        "pip-on-top@rafid.rafsan."
        "gsconnect@andyholmes.github.io"
    )
    if ! command -v gnome-extensions &> /dev/null; then
        warning "Comando 'gnome-extensions' não encontrado. Não é possível ativar as extensões."
        return
    fi
    for extension in "${EXTENSIONS_TO_ENABLE[@]}"; do
        if gnome-extensions info "$extension" &> /dev/null; then
            info "A ativar a extensão: $extension"
            gnome-extensions enable "$extension"
        else
            warning "Extensão $extension não encontrada. A saltar."
        fi
    done
    warning "Pode ser necessário reiniciar a sessão (logout/login) para que as extensões funcionem corretamente."
}

# ETAPA 13: CONFIGURAÇÃO DO LAYOUT DO TECLADO
step13_setup_keyboard() {
    ask_confirmation "Desejas adicionar o layout 'US International' (americano com ç)?"
    current_layouts=$(gsettings get org.gnome.desktop.input-sources sources)
    if [[ $current_layouts != *"('xkb', 'us+intl')"* ]]; then
        info "Adicionando layout de teclado 'US International'..."
        layouts_prefix=${current_layouts%]}
        new_layouts="$layouts_prefix, ('xkb', 'us+intl')]"
        gsettings set org.gnome.desktop.input-sources sources "$new_layouts"
    else
        info "Layout 'US International' já está configurado."
    fi
}

# ETAPA 14: CONFIGURAÇÕES DE APLICAÇÕES PADRÃO E GIT
step14_apply_personal_configs() {
    ask_confirmation "Desejas definir o Firefox como navegador padrão, configurar o Git e o VS Code?"
    # Firefox
    if ! is_installed_pacman firefox; then sudo pacman -S --needed --noconfirm firefox; fi
    if [[ $(xdg-settings get default-web-browser) != "firefox.desktop" ]]; then
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
        VSCODE_SETTINGS_FILE="$HOME/.config/Code/User/settings.json"
        mkdir -p "$(dirname "$VSCODE_SETTINGS_FILE")"
        [ ! -f "$VSCODE_SETTINGS_FILE" ] && echo "{}" > "$VSCODE_SETTINGS_FILE"
        info "A configurar a fonte e o auto-save no VS Code..."
        jq '."editor.fontFamily" = "MesloLGS NF, monospace" | ."terminal.integrated.fontFamily" = "MesloLGS NF, monospace" | ."files.autoSave" = "afterDelay"' \
           "$VSCODE_SETTINGS_FILE" > /tmp/vscode_settings.tmp && mv /tmp/vscode_settings.tmp "$VSCODE_SETTINGS_FILE"
    fi
}

# ETAPA 15: CONFIGURAÇÃO DE ENERGIA
step15_setup_power_settings() {
    ask_confirmation "Desejas aplicar as configurações de energia recomendadas (sem suspensão, ecrã desliga)?"
    info "A desativar a suspensão automática e a configurar o tempo de ecrã..."
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
    gsettings set org.gnome.desktop.session idle-delay 300 # 5 minutos
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 120 # 2 minutos
}

# ETAPA 16: CONFIGURAÇÃO DE SERVIÇOS DE INÍCIO AUTOMÁTICO
step16_setup_autostart() {
    if is_installed_yay rustdesk-bin; then
        ask_confirmation "Desejas que o RustDesk (acesso remoto) inicie automaticamente com o sistema?"
        # A resposta da confirmação está na variável $REPLY
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if ! systemctl is-enabled -q rustdesk.service; then
                info "A ativar o serviço do RustDesk..."
                sudo systemctl enable rustdesk.service
            else
                info "O serviço do RustDesk já está ativado."
            fi
        fi
    fi
}

# ===================================================================================
#                             EXECUÇÃO PRINCIPAL
# ===================================================================================
main() {
    clear
    echo -e "${C_BLUE}===================================================================${C_RESET}"
    echo -e "${C_BLUE}  Bem-vindo ao Script de Pós-Instalação para o Acer Nitro 5    ${C_RESET}"
    echo -e "${C_BLUE}===================================================================${C_RESET}"
    echo
    info "Este script irá instalar e configurar o teu ambiente de desenvolvimento."
    echo

    # --- Verificações Iniciais ---
    if [[ $EUID -eq 0 ]]; then
        error "Este script não deve ser executado como root. Use o teu utilizador normal."
        exit 1
    fi

    # Atualiza o timestamp do sudo para não pedir a senha repetidamente
    info "A pedir permissões de administrador para o restante do script..."
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    ask_confirmation "Desejas iniciar a configuração do sistema?"

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


    # --- Mensagem Final ---
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
    success "Aproveita o teu novo ambiente de desenvolvimento no Arch Linux!"
}

# --- Ponto de Entrada do Script ---
# Chama a função principal para iniciar a execução.
main
