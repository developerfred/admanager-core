#!/bin/bash

# Script de Deploy Simplificado para AdvertisementManager
# Uso: ./deploy.sh [network]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                       ║"
echo "║   █████╗ ██████╗     ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗   ║"
echo "║  ██╔══██╗██╔══██╗    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝   ║"
echo "║  ███████║██║  ██║    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗  ║"
echo "║  ██╔══██║██║  ██║    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║  ║"
echo "║  ██║  ██║██████╔╝    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝  ║"
echo "║  ╚═╝  ╚═╝╚═════╝     ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝   ║"
echo "║                                                                       ║"
echo "║                    DEPLOYMENT SCRIPT v1.0                             ║"
echo "║                                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar se .env existe
if [ ! -f .env ]; then
    echo -e "${RED}❌ Erro: Arquivo .env não encontrado!${NC}"
    echo -e "${YELLOW}💡 Copie .env.example para .env e configure suas variáveis${NC}"
    exit 1
fi

# Carregar .env
source .env

# Verificar PRIVATE_KEY
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ Erro: PRIVATE_KEY não definida no .env${NC}"
    exit 1
fi

# Função para mostrar menu
show_menu() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}    Selecione a Rede para Deploy${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
    
    echo -e "${GREEN}MAINNETS:${NC}"
    echo "  1) Celo Mainnet"
    echo "  2) Scroll Mainnet"
    echo "  3) Base Mainnet"
    echo "  4) Optimism Mainnet"
    echo "  5) Arbitrum One"
    echo "  6) Polygon Mainnet"
    echo "  7) Ethereum Mainnet"
    
    echo -e "\n${YELLOW}TESTNETS:${NC}"
    echo "  8) Celo Alfajores"
    echo "  9) Scroll Sepolia"
    echo "  10) Base Sepolia"
    echo "  11) Optimism Sepolia"
    echo "  12) Arbitrum Sepolia"
    echo "  13) Mumbai Testnet"
    echo "  14) Sepolia Testnet"
    
    echo -e "\n${RED}  0) Sair${NC}\n"
}

# Função para deploy
deploy_to_network() {
    local network_name=$1
    local rpc_url=$2
    local api_key=$3
    local chain_id=$4
    
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Deploying to ${network_name}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
    
    # Verificar se RPC está configurado
    if [ -z "$rpc_url" ]; then
        echo -e "${RED}❌ RPC URL não configurada para ${network_name}${NC}"
        echo -e "${YELLOW}💡 Configure no .env${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📡 RPC URL: ${rpc_url}${NC}"
    echo -e "${YELLOW}🔗 Chain ID: ${chain_id}${NC}\n"
    
    # Executar testes primeiro
    echo -e "${BLUE}🧪 Executando testes...${NC}"
    if ! forge test; then
        echo -e "${RED}❌ Testes falharam! Deploy cancelado.${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Testes passaram!${NC}\n"
    
    # Confirmar deploy
    echo -e "${YELLOW}⚠️  Você está prestes a fazer deploy em ${network_name}${NC}"
    read -p "Continuar? (s/N): " confirm
    
    if [[ ! $confirm =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Deploy cancelado${NC}"
        return 0
    fi
    
    # Deploy
    echo -e "\n${BLUE}🚀 Iniciando deploy...${NC}\n"
    
    if [ -z "$api_key" ]; then
        # Deploy sem verificação
        forge script script/DeployMultiChain.s.sol:DeployAdvertisementManager \
            --rpc-url "$rpc_url" \
            --broadcast \
            --legacy
    else
        # Deploy com verificação
        forge script script/DeployMultiChain.s.sol:DeployAdvertisementManager \
            --rpc-url "$rpc_url" \
            --broadcast \
            --verify \
            --etherscan-api-key "$api_key" \
            --legacy
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✅ Deploy concluído com sucesso!${NC}"
        echo -e "${BLUE}📝 Verifique deployments/ para os endereços${NC}\n"
        
        # Mostrar próximos passos
        echo -e "${YELLOW}═══════════════════════════════════════${NC}"
        echo -e "${YELLOW}  PRÓXIMOS PASSOS${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════${NC}"
        echo -e "1. Verifique o contrato no explorer"
        echo -e "2. Configure achievements iniciais"
        echo -e "3. Inicie o primeiro desafio comunitário"
        echo -e "4. Atualize seu frontend com o novo endereço"
        echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    else
        echo -e "\n${RED}❌ Deploy falhou!${NC}"
        return 1
    fi
}

# Menu principal
if [ -z "$1" ]; then
    while true; do
        show_menu
        read -p "Escolha uma opção: " choice
        
        case $choice in
            1) deploy_to_network "Celo Mainnet" "$CELO_RPC_URL" "$CELOSCAN_API_KEY" "42220" ;;
            2) deploy_to_network "Scroll Mainnet" "$SCROLL_RPC_URL" "$SCROLLSCAN_API_KEY" "534352" ;;
            3) deploy_to_network "Base Mainnet" "$BASE_RPC_URL" "$BASESCAN_API_KEY" "8453" ;;
            4) deploy_to_network "Optimism Mainnet" "$OPTIMISM_RPC_URL" "$OPTIMISTIC_ETHERSCAN_API_KEY" "10" ;;
            5) deploy_to_network "Arbitrum One" "$ARBITRUM_RPC_URL" "$ARBISCAN_API_KEY" "42161" ;;
            6) deploy_to_network "Polygon Mainnet" "$POLYGON_RPC_URL" "$POLYGONSCAN_API_KEY" "137" ;;
            7) deploy_to_network "Ethereum Mainnet" "$ETHEREUM_RPC_URL" "$ETHERSCAN_API_KEY" "1" ;;
            8) deploy_to_network "Celo Alfajores" "$CELO_ALFAJORES_RPC_URL" "$CELOSCAN_API_KEY" "44787" ;;
            9) deploy_to_network "Scroll Sepolia" "$SCROLL_SEPOLIA_RPC_URL" "$SCROLLSCAN_API_KEY" "534351" ;;
            10) deploy_to_network "Base Sepolia" "$BASE_SEPOLIA_RPC_URL" "$BASESCAN_API_KEY" "84532" ;;
            11) deploy_to_network "Optimism Sepolia" "$OPTIMISM_SEPOLIA_RPC_URL" "$OPTIMISTIC_ETHERSCAN_API_KEY" "11155420" ;;
            12) deploy_to_network "Arbitrum Sepolia" "$ARBITRUM_SEPOLIA_RPC_URL" "$ARBISCAN_API_KEY" "421614" ;;
            13) deploy_to_network "Mumbai Testnet" "$MUMBAI_RPC_URL" "$POLYGONSCAN_API_KEY" "80001" ;;
            14) deploy_to_network "Sepolia Testnet" "$SEPOLIA_RPC_URL" "$ETHERSCAN_API_KEY" "11155111" ;;
            0) 
                echo -e "\n${GREEN}👋 Até logo!${NC}\n"
                exit 0
                ;;
            *) 
                echo -e "${RED}❌ Opção inválida!${NC}"
                ;;
        esac
        
        echo -e "\n${YELLOW}Pressione ENTER para continuar...${NC}"
        read
    done
else
    # Deploy direto via argumento
    network=$1
    
    case $network in
        celo) deploy_to_network "Celo Mainnet" "$CELO_RPC_URL" "$CELOSCAN_API_KEY" "42220" ;;
        celo-testnet) deploy_to_network "Celo Alfajores" "$CELO_ALFAJORES_RPC_URL" "$CELOSCAN_API_KEY" "44787" ;;
        scroll) deploy_to_network "Scroll Mainnet" "$SCROLL_RPC_URL" "$SCROLLSCAN_API_KEY" "534352" ;;
        scroll-testnet) deploy_to_network "Scroll Sepolia" "$SCROLL_SEPOLIA_RPC_URL" "$SCROLLSCAN_API_KEY" "534351" ;;
        base) deploy_to_network "Base Mainnet" "$BASE_RPC_URL" "$BASESCAN_API_KEY" "8453" ;;
        base-testnet) deploy_to_network "Base Sepolia" "$BASE_SEPOLIA_RPC_URL" "$BASESCAN_API_KEY" "84532" ;;
        optimism) deploy_to_network "Optimism Mainnet" "$OPTIMISM_RPC_URL" "$OPTIMISTIC_ETHERSCAN_API_KEY" "10" ;;
        optimism-testnet) deploy_to_network "Optimism Sepolia" "$OPTIMISM_SEPOLIA_RPC_URL" "$OPTIMISTIC_ETHERSCAN_API_KEY" "11155420" ;;
        arbitrum) deploy_to_network "Arbitrum One" "$ARBITRUM_RPC_URL" "$ARBISCAN_API_KEY" "42161" ;;
        arbitrum-testnet) deploy_to_network "Arbitrum Sepolia" "$ARBITRUM_SEPOLIA_RPC_URL" "$ARBISCAN_API_KEY" "421614" ;;
        polygon) deploy_to_network "Polygon Mainnet" "$POLYGON_RPC_URL" "$POLYGONSCAN_API_KEY" "137" ;;
        polygon-testnet) deploy_to_network "Mumbai Testnet" "$MUMBAI_RPC_URL" "$POLYGONSCAN_API_KEY" "80001" ;;
        ethereum) deploy_to_network "Ethereum Mainnet" "$ETHEREUM_RPC_URL" "$ETHERSCAN_API_KEY" "1" ;;
        ethereum-testnet) deploy_to_network "Sepolia Testnet" "$SEPOLIA_RPC_URL" "$ETHERSCAN_API_KEY" "11155111" ;;
        *)
            echo -e "${RED}❌ Rede desconhecida: $network${NC}"
            echo -e "${YELLOW}💡 Redes disponíveis:${NC}"
            echo "  - celo, celo-testnet"
            echo "  - scroll, scroll-testnet"
            echo "  - base, base-testnet"
            echo "  - optimism, optimism-testnet"
            echo "  - arbitrum, arbitrum-testnet"
            echo "  - polygon, polygon-testnet"
            echo "  - ethereum, ethereum-testnet"
            exit 1
            ;;
    esac
fi
