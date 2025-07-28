#!/bin/bash

# ===================================================================================
#
#   SCRIPT DE PÓS-INSTALAÇÃO PARA ACER NITRO 5 (AMD+NVIDIA) COM ARCH LINUX + GNOME
#
#   Autor: Lucas A Pereira (aplucas)
#   Versão: 7.0
#
#   Este script automatiza a configuração de um ambiente de desenvolvimento completo,
#   otimizado para performance e gestão de bateria.
#   - v7.0: Alterado o modo gráfico padrão para 'NVIDIA' (dedicada) em vez de 'híbrido'.
#   - v6.9: Corrigido o nome do pacote de aceleração de vídeo da NVIDIA (removido o sufixo -git).
#   - v6.8: Corrigida a substituição do PulseAudio pelo PipeWire para ser feita numa única transação do pacman.
#   - v6.7: Corrigido conflito entre 'pipewire-pulse' e 'pulseaudio'.
#   - v6.6: Adicionada etapa explícita para unificação do áudio com PipeWire e 'ffmpeg'.
#   - v6.5: Adicionada instalação de drivers de aceleração de vídeo (VA-API).
#
# ===================================================================================

# --- Cores para uma melhor visualização ---
C_BLUE="\e[34m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_RESET="\e[0m"

# --- Contadores de Etapas ---
TOTAL_STEPS=20
CURRENT_STEP=1

# --- Funções de ajuda ---
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

ask_confirmation() {
    # Se a variável de ambiente YES for 'true', pula a pergunta.
    if [[ "$YES" == "true" ]]; then
        return 0
    fi
    read -p "$(echo -e "${C_YELLOW}[PERGUNTA]${C_RESET} $1 [S/n] ")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ && $REPLY != "" ]]; then
        error "Operação cancelada pelo utilizador."
        exit 1
    fi
}

# --- Banner de Início ---
clear
echo -e "${C_BLUE}===================================================================${C_RESET}"
echo -e "${C_BLUE}  Bem-vindo ao Script de Pós-Instalação para o Acer Nitro 5       ${C_RESET}"
echo -e "${C_BLUE}===================================================================${C_RESET}"
echo
info "Este script irá instalar e configurar o teu ambiente de desenvolvimento."
echo

# --- Verificação Inicial ---
if [[ $EUID -eq 0 ]]; then
   error "Este script não deve ser executado como root. Use o teu utilizador normal."
   exit 1
fi

# --- Início do Script ---
ask_confirmation "Desejas iniciar a configuração do sistema?"

# 1. ATUALIZAR O SISTEMA E INSTALAR DEPENDÊNCIAS BÁSICAS
# ========================================================
section_header "A atualizar o sistema e a instalar pacotes essenciais..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm git base-devel curl wget unzip jq

# 2. INSTALAR O AUR HELPER (yay)
# ========================================================
section_header "A instalar o AUR Helper (yay)..."
if ! command -v yay &> /dev/null; then
    info "O AUR Helper 'yay' não foi encontrado. A instalar..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    success "'yay' instalado com sucesso."
else
    info "'yay' já está instalado. A atualizar pacotes do AUR..."
    yay -Syu --noconfirm
fi

# 3. CONFIGURAÇÃO DOS GRÁFICOS DEDICADOS (NVIDIA)
# ========================================================
section_header "A configurar os drivers para usar a placa NVIDIA dedicada por padrão..."
ask_confirmation "Esta etapa irá instalar os drivers da NVIDIA e a ferramenta 'envycontrol' para forçar o uso da placa dedicada. Continuar?"

if ! is_installed_pacman nvidia-dkms; then
    sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils
else
    info "Driver da NVIDIA já está instalado."
fi

if ! is_installed_yay envycontrol; then
    yay -S --needed --noconfirm envycontrol
else
    info "'envycontrol' já está instalado."
fi

info "A verificar e definir o modo gráfico para 'NVIDIA' (dedicado)..."
if [[ $(envycontrol -q) != "nvidia" ]]; then
    warning "Modo atual não é 'NVIDIA'. A configurar..."
    sudo envycontrol -s nvidia
else
    info "O modo gráfico já está definido como 'NVIDIA'."
fi
success "Drivers da NVIDIA e 'envycontrol' configurados para usar a placa dedicada."
warning "É necessário REINICIAR o sistema para que a alteração tenha efeito."

# 4. CONFIGURAÇÃO DA ACELERAÇÃO DE VÍDEO (HARDWARE)
# ========================================================
section_header "A configurar a aceleração de vídeo por hardware (VA-API)..."
ask_confirmation "Desejas instalar os drivers para aceleração de vídeo (essencial para navegadores e players)?"

info "A instalar os drivers VA-API para a NVIDIA..."
# 'nvidia-vaapi-driver' é a implementação recomendada para a aceleração de vídeo em hardware NVIDIA
# 'libva-utils' fornece a ferramenta 'vainfo' para verificar a instalação
yay -S --needed --noconfirm libva-utils nvidia-vaapi-driver
success "Drivers de aceleração de vídeo instalados."
warning "Pode ser necessário reiniciar o navegador ou o sistema para que as alterações tenham efeito."

# 5. UNIFICAÇÃO DO SISTEMA DE ÁUDIO (PIPEWIRE)
# ========================================================
section_header "A unificar o sistema de áudio para PipeWire..."
ask_confirmation "Desejas instalar o PipeWire para uma gestão de áudio moderna (recomendado)?"

# Instala o conjunto completo do PipeWire. O pacman irá lidar com a substituição
# do pulseaudio por pipewire-pulse automaticamente, graças à flag --noconfirm.
info "A instalar o PipeWire e a substituir os pacotes de áudio existentes..."
sudo pacman -S --needed --noconfirm pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
success "Sistema de áudio configurado com PipeWire."


# 6. INSTALAÇÃO DAS LINGUAGENS DE PROGRAMAÇÃO E FERRAMENTAS
# ========================================================
section_header "A instalar ambientes de programação e ferramentas de linha de comando..."
ask_confirmation "Desejas instalar Python, Gemini CLI, Node.js (via nvm), Rust (com exa, bat, ytop), Go e Java?"

# Python
if ! is_installed_pacman python; then
    sudo pacman -S --needed --noconfirm python python-pip python-virtualenv
else
    info "Python já instalado."
fi

# Node.js (usando NVM para gestão de versões)
if [ ! -d "$HOME/.nvm" ]; then
    info "A instalar Node.js através do NVM (Node Version Manager)..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
else
    info "NVM já está instalado."
fi
# Carrega o NVM na sessão atual para poder usá-lo imediatamente
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Gemini CLI (via npm)
info "A instalar a ferramenta de linha de comando do Google Gemini (via npm)..."
if ! command -v gemini &> /dev/null; then
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
# Adiciona o cargo ao PATH da sessão atual para poder instalar as ferramentas
source "$HOME/.cargo/env"

# Ferramentas Rust
if ! command -v exa &> /dev/null; then cargo install exa; else info "'exa' já está instalado."; fi
if ! command -v bat &> /dev/null; then cargo install bat; else info "'bat' já está instalado."; fi
if ! command -v ytop &> /dev/null; then cargo install ytop; else info "'ytop' já está instalado."; fi

# Go
if ! is_installed_pacman go; then sudo pacman -S --needed --noconfirm go; else info "Go já instalado."; fi

# Java (OpenJDK)
if ! is_installed_pacman jdk-openjdk; then sudo pacman -S --needed --noconfirm jdk-openjdk; else info "Java (OpenJDK) já instalado."; fi

success "Verificação de ambientes de programação concluída."

# 7. FERRAMENTAS DE DESENVOLVIMENTO E PRODUTIVIDADE
# ========================================================
section_header "A instalar ferramentas de desenvolvimento e produtividade..."
ask_confirmation "Desejas instalar VS Code, Docker, DBeaver e Insomnia?"

if ! is_installed_yay visual-studio-code-bin; then yay -S --needed --noconfirm visual-studio-code-bin; else info "VS Code já instalado."; fi
if ! is_installed_pacman docker; then
    sudo pacman -S --needed --noconfirm docker docker-compose
    sudo systemctl enable --now docker.service
    sudo usermod -aG docker $USER
    warning "Para usar o Docker sem 'sudo', precisas de fazer logout e login novamente."
else
    info "Docker já instalado."
fi
if ! is_installed_yay dbeaver; then yay -S --needed --noconfirm dbeaver; else info "DBeaver já instalado."; fi
if ! is_installed_yay insomnia; then yay -S --needed --noconfirm insomnia; else info "Insomnia já instalado."; fi

success "Verificação de ferramentas de desenvolvimento concluída."

# 8. CONFIGURAÇÃO DO TERMINAL (ZSH + POWERLEVEL10K)
# ========================================================
section_header "A configurar um terminal moderno (ZSH + Powerlevel10k)..."
ask_confirmation "Desejas instalar e configurar o ZSH como terminal padrão?"

if ! is_installed_pacman zsh; then sudo pacman -S --needed --noconfirm zsh zsh-completions; else info "ZSH já instalado."; fi
if ! is_installed_yay ttf-meslo-nerd-font-powerlevel10k; then yay -S --needed --noconfirm ttf-meslo-nerd-font-powerlevel10k; else info "Fonte Meslo Nerd já instalada."; fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
if [ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ]; then git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM}/themes/powerlevel10k"; fi
if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]; then git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"; fi
if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]; then git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"; fi

info "A garantir que a configuração do .zshrc está correta..."
cat <<'EOF' > "$HOME/.zshrc"
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

# Verifica o shell padrão de forma robusta e altera apenas se necessário
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
ZSH_PATH=$(which zsh)
if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    info "A alterar o shell padrão para ZSH..."
    chsh -s "$ZSH_PATH"
    warning "O teu shell padrão foi alterado para ZSH. A alteração terá efeito no próximo login."
else
    info "O ZSH já é o shell padrão."
fi

success "Terminal configurado com ZSH + Powerlevel10k."

# 9. APLICAÇÕES ADICIONAIS
# ========================================================
section_header "A instalar aplicações adicionais..."
ask_confirmation "Desejas instalar LunarVim, Obsidian, RustDesk, FreeTube, Angry IP Scanner, Brave, Chrome, Edge, Teams e JetBrains Toolbox?"

# Instalação do LunarVim através do AUR, que é o método correto para Arch
info "A instalar LunarVim (via AUR)..."
if ! is_installed_yay lunarvim-git; then
    yay -S --needed --noconfirm lunarvim-git
else
    info "LunarVim já está instalado."
fi

if ! is_installed_pacman obsidian; then sudo pacman -S --needed --noconfirm obsidian; else info "Obsidian já instalado."; fi
if ! is_installed_yay rustdesk-bin; then yay -S --needed --noconfirm rustdesk-bin; else info "RustDesk já instalado."; fi
if ! is_installed_yay freetube-bin; then yay -S --needed --noconfirm freetube-bin; else info "FreeTube já instalado."; fi
if ! is_installed_yay ipscan; then yay -S --needed --noconfirm ipscan; else info "Angry IP Scanner (ipscan) já instalado."; fi
if ! is_installed_yay brave-bin; then yay -S --needed --noconfirm brave-bin; else info "Brave Browser já instalado."; fi
if ! is_installed_yay google-chrome; then yay -S --needed --noconfirm google-chrome; else info "Google Chrome já instalado."; fi
if ! is_installed_yay microsoft-edge-stable-bin; then yay -S --needed --noconfirm microsoft-edge-stable-bin; else info "Microsoft Edge já instalado."; fi
if ! is_installed_yay teams-for-linux; then yay -S --needed --noconfirm teams-for-linux; else info "Microsoft Teams já instalado."; fi
if ! is_installed_yay jetbrains-toolbox; then yay -S --needed --noconfirm jetbrains-toolbox; else info "JetBrains Toolbox já instalado."; fi

success "Verificação de aplicações adicionais concluída."

# 10. OTIMIZAÇÃO DO SISTEMA E FUNCIONALIDADES DO GNOME
# ========================================================
section_header "A otimizar o sistema e a adicionar funcionalidades ao GNOME..."
ask_confirmation "Desejas instalar ferramentas de gestão, personalização e funcionalidades avançadas do GNOME?"

# Instala o power-profiles-daemon como gestor de energia padrão, SE o TLP não estiver instalado
if ! is_installed_pacman tlp; then
    if ! is_installed_pacman power-profiles-daemon; then
        sudo pacman -S --needed --noconfirm power-profiles-daemon
        sudo systemctl enable --now power-profiles-daemon.service
    else
        info "'power-profiles-daemon' já instalado e ativo."
    fi
else
    warning "O TLP já está instalado. A saltar a instalação do 'power-profiles-daemon'."
fi


if ! is_installed_yay nbfc-linux-git; then
    yay -S --needed --noconfirm nbfc-linux-git
    sudo systemctl enable --now nbfc
else
    info "'nbfc-linux-git' já instalado e ativo."
fi

if ! is_installed_pacman gnome-tweaks; then sudo pacman -S --needed --noconfirm gnome-tweaks; else info "GNOME Tweaks já instalado."; fi

# Adiciona suporte para ícones de bandeja (AppIndicator)
info "A instalar suporte para AppIndicator (ícones de bandeja)..."
if ! is_installed_pacman gnome-shell-extension-appindicator; then
    sudo pacman -S --needed --noconfirm gnome-shell-extension-appindicator
else
    info "Extensão AppIndicator já instalada."
fi

# Adiciona extensão de histórico do clipboard (Clipboard History)
info "A instalar a extensão de histórico do clipboard (Clipboard History)..."
if ! is_installed_yay gnome-shell-extension-clipboard-history; then
    yay -S --needed --noconfirm gnome-shell-extension-clipboard-history
else
    info "Extensão Clipboard History já instalada."
fi

# Adiciona extensão de monitoramento de sistema
info "A instalar a extensão de monitoramento de sistema (Vitals)..."
if ! is_installed_yay gnome-shell-extension-vitals-git; then
    yay -S --needed --noconfirm gnome-shell-extension-vitals-git
else
    info "Extensão Vitals já instalada."
fi

# Adiciona funcionalidade de Tiling de Janelas (Pop!_OS)
info "A instalar a extensão de Tiling de Janelas (Pop Shell)..."
if ! is_installed_yay gnome-shell-extension-pop-shell; then
    yay -S --needed --noconfirm gnome-shell-extension-pop-shell
else
    info "Extensão Pop Shell já instalada."
fi

# Adiciona funcionalidade de Picture-in-Picture
info "A instalar a extensão de Picture-in-Picture..."
if ! is_installed_yay gnome-shell-extension-pip-on-top-git; then
    yay -S --needed --noconfirm gnome-shell-extension-pip-on-top-git
else
    info "Extensão Picture-in-Picture já instalada."
fi

# Adiciona funcionalidade de espelhamento de ecrã (Miracast/Chromecast)
info "A instalar a ferramenta de espelhamento de ecrã (Network Displays)..."
if ! is_installed_yay gnome-network-displays; then
    yay -S --needed --noconfirm gnome-network-displays
else
    info "Ferramenta Network Displays já instalada."
fi

success "Verificação de otimizações do sistema concluída."

# 11. INSTALAÇÃO DE CODECS MULTIMÍDIA
# ========================================================
section_header "A instalar codecs para compatibilidade multimídia..."
ask_confirmation "Desejas instalar os pacotes de codecs essenciais (ffmpeg, gstreamer)?"

# Pacotes GStreamer para a maioria das aplicações e ffmpeg para compatibilidade geral
sudo pacman -S --needed --noconfirm ffmpeg gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
success "Codecs multimídia instalados."

# 12. GESTÃO AVANÇADA DE ENERGIA (TLP)
# ========================================================
section_header "A configurar a gestão avançada de energia para notebooks (TLP)..."

# Pergunta ao utilizador, mas não sai do script se a resposta for 'não'.
read -p "$(echo -e "${C_YELLOW}[PERGUNTA]${C_RESET} Desejas instalar o TLP para uma gestão de bateria mais avançada? (Isto irá substituir 'power-profiles-daemon') [S/n] ")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ || $REPLY == "" ]]; then
    # O utilizador quer instalar o TLP
    if ! is_installed_pacman tlp; then
        # Remove o power-profiles-daemon para evitar conflitos
        if is_installed_pacman power-profiles-daemon; then
            warning "A remover 'power-profiles-daemon' para instalar o TLP..."
            sudo systemctl stop power-profiles-daemon.service
            sudo pacman -Rns --noconfirm power-profiles-daemon
        fi

        info "A instalar o TLP e o seu gestor de rádio..."
        sudo pacman -S --needed --noconfirm tlp tlp-rdw
        
        # Verifica se a instalação foi bem-sucedida antes de ativar o serviço
        if is_installed_pacman tlp; then
            info "A ativar o serviço do TLP..."
            sudo systemctl enable --now tlp.service
            success "TLP instalado e ativado."
        else
            error "A instalação do TLP falhou. A saltar a ativação do serviço."
        fi
    else
        info "TLP já está instalado."
    fi
else
    info "A saltar a instalação do TLP. O 'power-profiles-daemon' será mantido."
fi

# 13. CONFIGURAÇÃO DO BLUETOOTH
# ========================================================
section_header "A configurar o Bluetooth..."
ask_confirmation "Desejas instalar e ativar os serviços de Bluetooth?"

if ! is_installed_pacman bluez-utils; then
    sudo pacman -S --needed --noconfirm bluez bluez-utils
    sudo systemctl enable --now bluetooth.service
else
    info "Serviços de Bluetooth já instalados e ativos."
fi

success "Bluetooth configurado e ativado."

# 14. OTIMIZAÇÃO DE ÁUDIO (EASYEFFECTS)
# ========================================================
section_header "A configurar a otimização de áudio com EasyEffects..."
ask_confirmation "Desejas instalar o EasyEffects e um preset padrão para o microfone?"

if ! is_installed_pacman easyeffects; then
    info "A instalar o EasyEffects..."
    sudo pacman -S --needed --noconfirm easyeffects
else
    info "EasyEffects já está instalado."
fi

# Verifica se a instalação foi bem-sucedida antes de criar o preset
if is_installed_pacman easyeffects; then
    info "A criar um preset otimizado para o microfone..."
    EASYEFFECTS_INPUT_DIR="$HOME/.config/easyeffects/input"
    PRESET_FILE="$EASYEFFECTS_INPUT_DIR/Microfone Otimizado.json"

    mkdir -p "$EASYEFFECTS_INPUT_DIR"

    # Cria o ficheiro de preset JSON usando um here-doc
    cat <<'EOF' > "$PRESET_FILE"
{
    "input": {
        "plugins_order": [
            "gate",
            "echo_canceller",
            "compressor",
            "equalizer"
        ]
    },
    "gate": {
        "attack": 20.0,
        "bypass": false,
        "dry": 0.0,
        "input_gain": 0.0,
        "output_gain": 0.0,
        "range": -90.0,
        "ratio": 2.0,
        "release": 250.0,
        "threshold": -45.0,
        "wet": 100.0
    },
    "echo_canceller": {
        "bypass": false,
        "dry": 0.0,
        "input_gain": 0.0,
        "output_gain": 0.0,
        "wet": 100.0
    },
    "compressor": {
        "attack": 5.0,
        "bypass": false,
        "dry": 0.0,
        "input_gain": 0.0,
        "knee": 6.0,
        "output_gain": 6.0,
        "ratio": 4.0,
        "release": 100.0,
        "threshold": -20.0,
        "wet": 100.0
    },
    "equalizer": {
        "bands": [
            {
                "frequency": 120.0,
                "gain": 3.0,
                "mode": "RLC (BT, RBJ)",
                "q": 0.7,
                "slope": "x1",
                "type": "Lowshelf",
                "width": 2.4
            },
            {
                "frequency": 5000.0,
                "gain": 2.0,
                "mode": "RLC (BT, RBJ)",
                "q": 0.7,
                "slope": "x1",
                "type": "Highshelf",
                "width": 2.4
            }
        ],
        "bypass": false,
        "dry": 0.0,
        "input_gain": 0.0,
        "mode": "IIR",
        "num_bands": 2,
        "output_gain": 0.0,
        "split": false,
        "wet": 100.0
    }
}
EOF
    success "Preset 'Microfone Otimizado' criado com sucesso."
    warning "Para usar, abre o EasyEffects, vai para a secção 'Entrada' e seleciona o preset 'Microfone Otimizado'."
fi


# 15. INTEGRAÇÃO COM ANDROID (KDE CONNECT)
# ========================================================
section_header "A configurar a integração com o Android (KDE Connect)..."
ask_confirmation "Desejas instalar o KDE Connect e a integração GSConnect para o GNOME?"

if ! is_installed_pacman kdeconnect; then
    sudo pacman -S --needed --noconfirm kdeconnect
else
    info "KDE Connect já está instalado."
fi

if ! is_installed_yay gnome-shell-extension-gsconnect; then
    yay -S --needed --noconfirm gnome-shell-extension-gsconnect
else
    info "Extensão GSConnect já está instalada."
fi

success "Integração com Android (KDE Connect) configurada."

# 16. CONFIGURAÇÃO DO LAYOUT DO TECLADO
# ========================================================
section_header "A configurar layouts de teclado adicionais..."
ask_confirmation "Desejas adicionar o layout 'US International' (americano com ç)?"

current_layouts=$(gsettings get org.gnome.desktop.input-sources sources)
if [[ $current_layouts != *"('xkb', 'us+intl')"* ]]; then
    info "Adicionando layout de teclado 'US International'..."
    # Remove o ']' final da string atual
    layouts_prefix=${current_layouts%]}
    # Adiciona o novo layout e fecha a string
    new_layouts="$layouts_prefix, ('xkb', 'us+intl')]"
    gsettings set org.gnome.desktop.input-sources sources "$new_layouts"
    success "Layout 'US International' adicionado."
else
    info "Layout de teclado 'US International' já está configurado."
fi

# 17. CONFIGURAÇÕES DE APLICAÇÕES PADRÃO E GIT
# ========================================================
section_header "A aplicar configurações pessoais..."
ask_confirmation "Desejas definir o Firefox como navegador padrão, configurar o Git e o VS Code?"

# Instala o Firefox se necessário
if ! is_installed_pacman firefox; then
    sudo pacman -S --needed --noconfirm firefox
else
    info "Firefox já está instalado."
fi

# Define o Firefox como padrão
if [[ $(xdg-settings get default-web-browser) != "firefox.desktop" ]]; then
    info "A definir o Firefox como navegador padrão..."
    xdg-settings set default-web-browser firefox.desktop
else
    info "Firefox já é o navegador padrão."
fi

# Configura o Git
if ! git config --global --get user.name >/dev/null 2>&1; then
    info "O nome de utilizador do Git não está configurado."
    read -p "  -> Insere o teu nome para o Git [Lucas A Pereira]: " git_name
    # Se o input for vazio, usa o valor padrão
    git_name=${git_name:-"Lucas A Pereira"}
    git config --global user.name "$git_name"
    success "Nome de utilizador do Git definido como: $git_name"
else
    info "Nome de utilizador do Git já está configurado: $(git config --global user.name)"
fi

if ! git config --global --get user.email >/dev/null 2>&1; then
    info "O email do Git não está configurado."
    read -p "  -> Insere o teu email para o Git [l.alexandre100@gmail.com]: " git_email
    # Se o input for vazio, usa o valor padrão
    git_email=${git_email:-"l.alexandre100@gmail.com"}
    git config --global user.email "$git_email"
    success "Email do Git definido como: $git_email"
else
    info "Email do Git já está configurado: $(git config --global user.email)"
fi

# Configura a fonte e o auto-save do VS Code se ele estiver instalado
if is_installed_yay visual-studio-code-bin; then
    VSCODE_SETTINGS_FILE="$HOME/.config/Code/User/settings.json"
    VSCODE_SETTINGS_DIR=$(dirname "$VSCODE_SETTINGS_FILE")
    FONT_FAMILY="MesloLGS NF, monospace"
    AUTO_SAVE_SETTING="afterDelay"

    # Garante que o diretório e um ficheiro de configurações base existem
    mkdir -p "$VSCODE_SETTINGS_DIR"
    if [ ! -f "$VSCODE_SETTINGS_FILE" ]; then
        echo "{}" > "$VSCODE_SETTINGS_FILE"
    fi

    # Verifica as configurações atuais
    current_editor_font=$(jq -r '."editor.fontFamily"' "$VSCODE_SETTINGS_FILE")
    current_terminal_font=$(jq -r '."terminal.integrated.fontFamily"' "$VSCODE_SETTINGS_FILE")
    current_auto_save=$(jq -r '."files.autoSave"' "$VSCODE_SETTINGS_FILE")

    if [[ "$current_editor_font" != "$FONT_FAMILY" || "$current_terminal_font" != "$FONT_FAMILY" || "$current_auto_save" != "$AUTO_SAVE_SETTING" ]]; then
        info "A configurar a fonte e o auto-save no VS Code..."
        jq --arg font "$FONT_FAMILY" --arg autosave "$AUTO_SAVE_SETTING" \
           '."editor.fontFamily" = $font | ."terminal.integrated.fontFamily" = $font | ."files.autoSave" = $autosave' \
           "$VSCODE_SETTINGS_FILE" > /tmp/vscode_settings.tmp && mv /tmp/vscode_settings.tmp "$VSCODE_SETTINGS_FILE"
    else
        info "Fonte e auto-save do VS Code já estão configurados."
    fi
fi
success "Configurações pessoais aplicadas."


# 18. CONFIGURAÇÃO DE ENERGIA
# ========================================================
section_header "A configurar a gestão de energia..."
ask_confirmation "Desejas aplicar as configurações de energia recomendadas (sem suspensão, ecrã desliga)?"

info "A desativar a suspensão automática por inatividade..."
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'

info "A configurar o tempo para desligar o ecrã..."
# 300 segundos = 5 minutos
gsettings set org.gnome.desktop.session idle-delay 300
# 120 segundos = 2 minutos
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 120

warning "As configurações de energia foram aplicadas. O modo 'Economia de Energia' pode usar um tempo de ecrã mais curto."
success "Gestão de energia configurada."

# 19. ATIVAR MODO PERFORMANCE (AMD P-STATE)
# ========================================================
section_header "A otimizar a performance do CPU AMD..."
ask_confirmation "Desejas ativar o AMD P-State para teres acesso ao modo 'Performance'?"

# Deteta o gestor de arranque
if [ -d "/boot/grub" ]; then
    BOOTLOADER="grub"
elif [ -d "/boot/loader" ]; then
    BOOTLOADER="systemd-boot"
else
    BOOTLOADER="unknown"
fi

case "$BOOTLOADER" in
    grub)
        GRUB_FILE="/etc/default/grub"
        if ! grep -q "amd_pstate=guided" "$GRUB_FILE"; then
            info "Detetado GRUB. A adicionar o parâmetro do kernel 'amd_pstate=guided'..."
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_pstate=guided"/' "$GRUB_FILE"
            info "A regenerar a configuração do GRUB..."
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            success "AMD P-State ativado para GRUB. Estará disponível após o reinício."
        else
            info "O AMD P-State já está ativado na configuração do GRUB."
        fi
        ;;
    systemd-boot)
        ENTRY_FILE=$(find /boot/loader/entries -maxdepth 1 -type f -name "*.conf" | head -n 1)
        if [ -n "$ENTRY_FILE" ]; then
            if ! grep -q "amd_pstate=guided" "$ENTRY_FILE"; then
                info "Detetado systemd-boot. A adicionar 'amd_pstate=guided' a $ENTRY_FILE..."
                sudo sed -i '/^options/ s/$/ amd_pstate=guided/' "$ENTRY_FILE"
                success "Parâmetro do kernel adicionado para systemd-boot. Estará disponível após o reinício."
            else
                info "O AMD P-State já está ativado em "$ENTRY_FILE"."
            fi
        else
            warning "Não foi encontrado nenhum ficheiro de entrada .conf em /boot/loader/entries/."
        fi
        ;;
    *)
        warning "Não foi possível detetar o gestor de arranque (GRUB ou systemd-boot). A ativação do AMD P-State terá de ser feita manualmente."
        ;;
esac


# 20. CONFIGURAÇÃO DE SERVIÇOS DE INÍCIO AUTOMÁTICO
# ========================================================
section_header "A configurar serviços de início automático..."
if is_installed_yay rustdesk-bin; then
    ask_confirmation "Desejas que o RustDesk (acesso remoto) inicie automaticamente com o sistema?"
    # A resposta da confirmação está na variável $REPLY
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if ! systemctl is-enabled -q rustdesk.service; then
            info "A ativar o serviço do RustDesk..."
            sudo systemctl enable rustdesk.service
            success "Serviço do RustDesk ativado."
        else
            info "O serviço do RustDesk já está ativado."
        fi
    fi
fi


# --- Mensagem Final ---
echo
echo -e "${C_GREEN}===================================================================${C_RESET}"
echo -e "${C_GREEN}      SETUP CONCLUÍDO COM SUCESSO!                                 ${C_RESET}"
echo -e "${C_GREEN}===================================================================${C_RESET}"
echo
info "Resumo e Próximos Passos:"
echo -e "1.  ${C_RED}REINICIA O TEU COMPUTADOR AGORA${C_RESET} para aplicar todas as alterações."
echo "    - Após o reinício, os drivers, o novo shell, as novas extensões e o modo performance estarão ativos."
echo
echo -e "2.  ${C_YELLOW}Ativar as Novas Extensões e Presets:${C_RESET}"
echo "    - As extensões (Clipboard, Vitals, etc.) podem precisar ser ativadas na app 'Extensões'."
echo -e "    - Para o áudio, abre o ${C_GREEN}EasyEffects${C_RESET}, vai à secção 'Entrada' e, na área de Presets, seleciona 'Microfone Otimizado'."
echo
echo -e "3.  ${C_YELLOW}Funcionalidades Avançadas:${C_RESET}"
echo "    - ${C_GREEN}Tiling de Janelas:${C_RESET} Procura um novo ícone na barra superior para ativar/desativar o tiling."
echo "    - ${C_GREEN}Picture-in-Picture:${C_RESET} Procura pelo ícone de PiP em vídeos (ex: no YouTube no Firefox)."
echo "    - ${C_GREEN}Espelhamento de Ecrã:${C_RESET} Abre as 'Definições' > 'Ecrãs' e procura a opção para te conectares a um ecrã sem fios."
echo
echo -e "4.  ${C_YELLOW}Conectar com o Android:${C_RESET}"
echo "    - Instala a app 'KDE Connect' no teu Android a partir da Play Store."
echo "    - Certifica-te que ambos os dispositivos estão na mesma rede Wi-Fi e emparelha-os."
echo
echo -e "5.  ${C_YELLOW}Primeiro Login com o Novo Terminal:${C_RESET}"
echo "    - Os teus comandos 'ls' e 'cat' agora usarão 'exa' e 'bat' automaticamente."
echo "    - O assistente do ${C_GREEN}Powerlevel10k${C_RESET} pode iniciar. Se não, executa: ${C_GREEN}p10k configure${C_RESET}"
echo
echo -e "6.  ${C_YELLOW}Gestão da Placa de Vídeo (envycontrol):${C_RESET}"
echo -e "    - ${C_GREEN}Modo NVIDIA (padrão):${C_RESET} A placa de vídeo dedicada estará sempre ativa para máxima performance."
echo -e "    - Para mudar para o modo de economia (duração da bateria), executa: ${C_GREEN}sudo envycontrol -s integrated${C_RESET} (e reinicia)."
echo -e "    - Para mudar para o modo híbrido (equilíbrio), executa: ${C_GREEN}sudo envycontrol -s hybrid${C_RESET} (e reinicia)."
echo
echo -e "7.  ${C_YELLOW}Layout de Teclado:${C_RESET}"
echo "    - O layout 'US International' foi adicionado. Pressiona ${C_GREEN}Super + Espaço${C_RESET} para alternar entre os layouts."
echo
echo -e "8.  ${C_YELLOW}Modo Performance:${C_RESET}"
echo "    - Após o reinício, quando o notebook estiver ligado à corrente, o modo 'Performance' deve aparecer no menu de energia."
echo
echo -e "9.  ${C_YELLOW}Google Gemini CLI:${C_RESET}"
echo "    - Para usares a CLI do Gemini, primeiro precisas de a configurar com a tua API Key."
echo "    - Executa no terminal: ${C_GREEN}gemini init${C_RESET} e segue as instruções."
echo
success "Aproveita o teu novo ambiente de desenvolvimento no Arch Linux!"
