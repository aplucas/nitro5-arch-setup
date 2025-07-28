#!/bin/bash

# ===================================================================================
#
#   SCRIPT DE PÓS-INSTALAÇÃO PARA ACER NITRO 5 (AMD+NVIDIA) COM ARCH LINUX + GNOME
#
#   Autor: O Teu Parceiro de Programação (Gemini)
#   Versão: 4.7
#
#   Este script automatiza a configuração de um ambiente de desenvolvimento completo,
#   otimizado para performance e gestão de bateria.
#   - v4.7: Adicionada configuração de auto-save no VS Code.
#   - v4.6: Adicionada opção para ativar o serviço do RustDesk no arranque.
#   - v4.5: Adicionada configuração automática da fonte 'MesloLGS NF' no VS Code.
#   - v4.4: Adicionada etapa para ativar o modo Performance (AMD P-State).
#   - v4.3: Adicionada configuração do Firefox como padrão e definições globais do Git.
#   - v4.2: Adicionada etapa para configurar a gestão de energia (suspensão e ecrã).
#   - v4.1: Adicionada instalação do RustDesk.
#   - v4.0: Corrigida instalação do gnome-network-displays (movido para o AUR).
#   - v3.9: Substituída a extensão de clipboard 'Pano' (com erro de compilação) por 'Clipboard History'.
#   - v3.8: Otimizada a etapa de configuração da GPU para não ser executada desnecessariamente.
#   - v3.7: Adicionada ferramenta de espelhamento de ecrã (gnome-network-displays).
#   - v3.6: Adicionada instalação do Obsidian.
#   - v3.5: Corrigidos nomes de pacotes de extensões GNOME (Pano e PiP) no AUR.
#   - v3.4: Corrigida instalação do LunarVim usando o pacote do AUR para evitar erros de pip.
#   - v3.3: Corrigida instalação do GSConnect (movido para o AUR).
#   - v3.2: Corrigida instalação de extensões GNOME (Clipboard e PiP) movendo para o AUR.
#   - v3.1: Corrigido erro 'externally-managed-environment' ao instalar LunarVim.
#   - v3.0: Corrigidas cores na mensagem final; Adicionado layout de teclado US-Intl.
#   - v2.9: Adicionada instalação do FreeTube.
#   - v2.8: Adicionada atualização do pip e instalação do Brave Browser.
#   - v2.7: Adicionadas extensões para Tiling de Janelas (Pop Shell) e Picture-in-Picture.
#   - v2.6: Adicionada instalação do KDE Connect e integração GSConnect para o GNOME.
#   - v2.5: Adicionadas extensões GNOME para clipboard e monitor de sistema.
#   - v2.4: Adicionado suporte para AppIndicator/ícones de bandeja no GNOME.
#   - v2.3: Adicionada instalação de ferramentas Rust (exa, bat, ytop) e aliases.
#   - v2.2: Tornou o script idempotente (pode ser executado várias vezes).
#   - v2.1: Adicionada etapa de configuração do Bluetooth.
#   - v2.0: Adicionado terminal ZSH+Powerlevel10k e novas aplicações.
#
# ===================================================================================

# --- Cores para uma melhor visualização ---
C_BLUE="\e[34m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_RESET="\e[0m"

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
info "A atualizar o sistema e a instalar pacotes essenciais..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm git base-devel curl wget unzip jq

# 2. INSTALAR O AUR HELPER (yay)
# ========================================================
if ! command -v yay &> /dev/null; then
    info "O AUR Helper 'yay' não foi encontrado. A instalar..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    success "'yay' instalado com sucesso."
else
    info "'yay' já está instalado. A atualizar pacotes do AUR..."
    yay -Syu --noconfirm
fi

# 3. CONFIGURAÇÃO DOS GRÁFICOS HÍBRIDOS (NVIDIA)
# ========================================================
info "A configurar os drivers da NVIDIA para gráficos híbridos..."
ask_confirmation "Esta etapa irá instalar os drivers da NVIDIA e a ferramenta 'envycontrol'. Continuar?"

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

info "A verificar e definir o modo gráfico para 'híbrido'..."
if [[ $(envycontrol -q) != "hybrid" ]]; then
    warning "Modo atual não é 'híbrido'. A configurar..."
    sudo envycontrol -s hybrid
else
    info "O modo gráfico já está definido como 'híbrido'."
fi
success "Drivers da NVIDIA e 'envycontrol' configurados."
warning "É necessário REINICIAR o sistema para que os drivers da NVIDIA funcionem corretamente."

# 4. INSTALAÇÃO DAS LINGUAGENS DE PROGRAMAÇÃO
# ========================================================
info "A instalar ambientes de programação..."
ask_confirmation "Desejas instalar Python, Node.js (via nvm), Rust, Go e Java?"

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

# Rust (usando rustup)
if [ ! -d "$HOME/.cargo" ]; then
    info "A instalar Rust através do 'rustup'..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
else
    info "Rust (rustup) já está instalado."
fi
# Adiciona o cargo ao PATH da sessão atual para poder instalar as ferramentas
source "$HOME/.cargo/env"

# Go
if ! is_installed_pacman go; then sudo pacman -S --needed --noconfirm go; else info "Go já instalado."; fi

# Java (OpenJDK)
if ! is_installed_pacman jdk-openjdk; then sudo pacman -S --needed --noconfirm jdk-openjdk; else info "Java (OpenJDK) já instalado."; fi

success "Verificação de ambientes de programação concluída."

# 4.1 INSTALAÇÃO DE FERRAMENTAS RUST
# ========================================================
info "A instalar ferramentas de linha de comando escritas em Rust..."
ask_confirmation "Desejas instalar exa, bat e ytop?"

if ! command -v exa &> /dev/null; then cargo install exa; else info "'exa' já está instalado."; fi
if ! command -v bat &> /dev/null; then cargo install bat; else info "'bat' já está instalado."; fi
if ! command -v ytop &> /dev/null; then cargo install ytop; else info "'ytop' já está instalado."; fi

success "Verificação de ferramentas Rust concluída."


# 5. FERRAMENTAS DE DESENVOLVIMENTO E PRODUTIVIDADE
# ========================================================
info "A instalar ferramentas de desenvolvimento..."
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

# 6. CONFIGURAÇÃO DO TERMINAL (ZSH + POWERLEVEL10K)
# ========================================================
info "A configurar um terminal moderno (ZSH + Powerlevel10k)..."
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

if [ "$SHELL" != "/bin/zsh" ]; then
    chsh -s $(which zsh)
    warning "O teu shell padrão foi alterado para ZSH. A alteração terá efeito no próximo login."
fi

success "Terminal configurado com ZSH + Powerlevel10k."

# 7. APLICAÇÕES ADICIONAIS
# ========================================================
info "A instalar aplicações adicionais..."
ask_confirmation "Desejas instalar LunarVim, Obsidian, RustDesk, FreeTube, Brave, Chrome, Edge, Teams e JetBrains Toolbox?"

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
if ! is_installed_yay brave-bin; then yay -S --needed --noconfirm brave-bin; else info "Brave Browser já instalado."; fi
if ! is_installed_yay google-chrome; then yay -S --needed --noconfirm google-chrome; else info "Google Chrome já instalado."; fi
if ! is_installed_yay microsoft-edge-stable-bin; then yay -S --needed --noconfirm microsoft-edge-stable-bin; else info "Microsoft Edge já instalado."; fi
if ! is_installed_yay teams-for-linux; then yay -S --needed --noconfirm teams-for-linux; else info "Microsoft Teams já instalado."; fi
if ! is_installed_yay jetbrains-toolbox; then yay -S --needed --noconfirm jetbrains-toolbox; else info "JetBrains Toolbox já instalado."; fi

success "Verificação de aplicações adicionais concluída."

# 8. OTIMIZAÇÃO DO SISTEMA E FUNCIONALIDADES DO GNOME
# ========================================================
info "A otimizar o sistema para uso em notebook e a adicionar funcionalidades ao GNOME..."
ask_confirmation "Desejas instalar ferramentas de gestão, personalização e funcionalidades avançadas do GNOME?"

if ! is_installed_pacman power-profiles-daemon; then
    sudo pacman -S --needed --noconfirm power-profiles-daemon
    sudo systemctl enable --now power-profiles-daemon.service
else
    info "'power-profiles-daemon' já instalado e ativo."
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

# 9. CONFIGURAÇÃO DO BLUETOOTH
# ========================================================
info "A configurar o Bluetooth..."
ask_confirmation "Desejas instalar e ativar os serviços de Bluetooth?"

if ! is_installed_pacman bluez; then
    sudo pacman -S --needed --noconfirm bluez bluez-utils pipewire-pulse
    sudo systemctl enable --now bluetooth.service
else
    info "Serviços de Bluetooth já instalados e ativos."
fi

success "Bluetooth configurado e ativado."

# 10. INTEGRAÇÃO COM ANDROID (KDE CONNECT)
# ========================================================
info "A configurar a integração com o Android..."
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

# 11. CONFIGURAÇÃO DO LAYOUT DO TECLADO
# ========================================================
info "A configurar layouts de teclado adicionais..."
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

# 12. CONFIGURAÇÕES DE APLICAÇÕES PADRÃO E GIT
# ========================================================
info "A aplicar configurações pessoais..."
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
if [[ $(git config --global user.name) != "Lucas A Pereira" ]]; then
    info "A configurar o nome de utilizador do Git..."
    git config --global user.name "Lucas A Pereira"
else
    info "Nome de utilizador do Git já está configurado."
fi

if [[ $(git config --global user.email) != "l.alexandre100@gmail.com" ]]; then
    info "A configurar o email do Git..."
    git config --global user.email "l.alexandre100@gmail.com"
else
    info "Email do Git já está configurado."
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


# 13. CONFIGURAÇÃO DE ENERGIA
# ========================================================
info "A configurar a gestão de energia..."
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

# 14. ATIVAR MODO PERFORMANCE (AMD P-STATE)
# ========================================================
info "A otimizar a performance do CPU AMD..."
ask_confirmation "Desejas ativar o AMD P-State para teres acesso ao modo 'Performance'?"

GRUB_FILE="/etc/default/grub"
if ! grep -q "amd_pstate=active" "$GRUB_FILE"; then
    info "A adicionar o parâmetro do kernel 'amd_pstate=active'..."
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_pstate=active"/' "$GRUB_FILE"
    info "A regenerar a configuração do GRUB..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    success "AMD P-State ativado. O modo 'Performance' estará disponível após o reinício."
else
    info "O AMD P-State já está ativado na configuração do GRUB."
fi

# 15. CONFIGURAÇÃO DE SERVIÇOS DE INÍCIO AUTOMÁTICO
# ========================================================
info "A configurar serviços de início automático..."
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
echo -e "2.  ${C_YELLOW}Ativar as Novas Extensões:${C_RESET}"
echo "    - As novas extensões (Clipboard History, Vitals, GSConnect, Pop Shell, etc.) podem precisar ser ativadas."
echo "    - Abre a aplicação 'Extensões' ou 'Ajustes' (Tweaks) para as ligares e configurares."
echo
echo -e "3.  ${C_YELLOW}Funcionalidades Avançadas:${C_RESET}"
echo -e "    - ${C_GREEN}Tiling de Janelas:${C_RESET} Procura um novo ícone na barra superior para ativar/desativar o tiling."
echo -e "    - ${C_GREEN}Picture-in-Picture:${C_RESET} Procura pelo ícone de PiP em vídeos (ex: no YouTube no Firefox, ou na app Clapper)."
echo -e "    - ${C_GREEN}Espelhamento de Ecrã:${C_RESET} Abre as 'Definições' > 'Ecrãs' e procura a opção para te conectares a um ecrã sem fios."
echo
echo -e "4.  ${C_YELLOW}Conectar com o Android:${C_RESET}"
echo "    - Instala a app 'KDE Connect' no teu Android a partir da Play Store."
echo "    - Certifica-te que ambos os dispositivos estão na mesma rede Wi-Fi e emparelha-os."
echo
echo -e "5.  ${C_YELLOW}Primeiro Login com o Novo Terminal:${C_RESET}"
echo "    - Os teus comandos 'ls' e 'cat' agora usarão 'exa' e 'bat' automaticamente."
echo -e "    - O assistente do ${C_GREEN}Powerlevel10k${C_RESET} pode iniciar. Se não, executa: ${C_GREEN}p10k configure${C_RESET}"
echo
echo -e "6.  ${C_YELLOW}Gestão da Placa de Vídeo (envycontrol):${C_RESET}"
echo "    - Modo Híbrido (atual): 'prime-run <comando>' para usar a NVIDIA."
echo "    - Modo de Economia: ${C_GREEN}sudo envycontrol -s integrated${C_RESET} (e reinicia)."
echo
echo -e "7.  ${C_YELLOW}Layout de Teclado:${C_RESET}"
echo -e "    - O layout 'US International' foi adicionado. Pressiona ${C_GREEN}Super + Espaço${C_RESET} para alternar entre os layouts."
echo
echo -e "8.  ${C_YELLOW}Modo Performance:${C_RESET}"
echo -e "    - Após o reinício, quando o notebook estiver ligado à corrente, o modo 'Performance' deve aparecer no menu de energia."
echo
success "Aproveita o teu novo ambiente de desenvolvimento no Arch Linux!"

