# Script de Pós-Instalação para Acer Nitro 5 (Arch Linux + GNOME)

Este script automatiza a configuração de um ambiente de desenvolvimento e produtividade em uma instalação do Arch Linux com GNOME, otimizado para o hardware do **Acer Nitro 5 (AMD + NVIDIA)**.

## Principais Funcionalidades

- **Idempotente:** O script verifica se cada componente já está instalado, permitindo que seja executado várias vezes com segurança.
- **Interativo:** Pede confirmação antes de cada etapa principal, dando-lhe controlo total sobre as alterações.
- **Sistema:** Atualização completa, instalação do `yay` e dependências essenciais.
- **Gráficos Híbridos:** Instalação dos drivers NVIDIA e configuração do `envycontrol`.
- **Ambiente de Desenvolvimento:** Python, Node.js (via NVM), Rust, Go, Java, Docker, VS Code, DBeaver, Insomnia e a CLI do Google Gemini.
- **Terminal:** Configuração do ZSH com Oh My Zsh, Powerlevel10k e ferramentas como `exa` e `bat`.
- **Aplicações:** Instalação de LunarVim, Obsidian, navegadores (Brave, Chrome, Edge), RustDesk, entre outros.
- **Otimizações GNOME:** Adiciona extensões para tiling de janelas (Pop Shell), clipboard, monitor de sistema (Vitals) e integração com Android (GSConnect).
- **Otimizações de Hardware:** Ativa o `amd_pstate` para o modo performance e configura a gestão de energia e ventoinhas (`nbfc`).

> **Nota sobre a Configuração do Git:** O script irá solicitar as suas credenciais globais do Git (`user.name` e `user.email`) caso elas ainda não estejam configuradas, sugerindo os dados do autor como padrão.

## Como Usar

1.  **Dar permissão de execução:**
    ```bash
    chmod +x nitro5-arch-setup.sh
    ```

2.  **Executar o script (sem sudo):**
    ```bash
    ./nitro5-arch-setup.sh
    ```

3.  **Seguir as instruções:** O script é interativo e pedirá confirmação para cada etapa principal.

## Pós-Instalação

Após a execução, **REINICIE O COMPUTADOR** para aplicar todas as alterações, especialmente os drivers da NVIDIA e a mudança para o shell ZSH.
