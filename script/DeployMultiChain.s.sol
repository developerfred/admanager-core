// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {AdvertisementManager} from "../src/AdvertisementManager.sol";

/**
 * @title DeployAdvertisementManager
 * @notice Script de deploy para múltiplas redes EVM
 *
 * Redes suportadas:
 * - Celo Mainnet & Alfajores (Testnet)
 * - Scroll Mainnet & Sepolia (Testnet)
 * - Base Mainnet & Sepolia (Testnet)
 * - Optimism Mainnet & Sepolia (Testnet)
 * - Arbitrum One & Sepolia (Testnet)
 * - Polygon & Mumbai (Testnet)
 * - Ethereum Mainnet & Sepolia
 *
 * Como usar:
 * 1. Configure seu .env com PRIVATE_KEY e as RPC_URLs
 * 2. Execute: forge script script/DeployMultiChain.s.sol:DeployAdvertisementManager --rpc-url <network> --broadcast --verify
 *
 * Exemplos:
 * forge script script/DeployMultiChain.s.sol:DeployAdvertisementManager --rpc-url $CELO_RPC_URL --broadcast --verify
 * forge script script/DeployMultiChain.s.sol:DeployAdvertisementManager --rpc-url $SCROLL_RPC_URL --broadcast --verify
 * forge script script/DeployMultiChain.s.sol:DeployAdvertisementManager --rpc-url $BASE_RPC_URL --broadcast --verify
 */
contract DeployAdvertisementManager is Script {
    // Estrutura para armazenar informações de rede
    struct NetworkConfig {
        string name;
        uint256 chainId;
        bool isTestnet;
    }

    // Mapeamento de chain IDs para configurações
    mapping(uint256 => NetworkConfig) public networkConfigs;

    function setUp() public {
        // Celo
        networkConfigs[42220] = NetworkConfig("Celo Mainnet", 42220, false);
        networkConfigs[44787] = NetworkConfig("Celo Alfajores", 44787, true);

        // Scroll
        networkConfigs[534352] = NetworkConfig("Scroll Mainnet", 534352, false);
        networkConfigs[534351] = NetworkConfig("Scroll Sepolia", 534351, true);

        // Base
        networkConfigs[8453] = NetworkConfig("Base Mainnet", 8453, false);
        networkConfigs[84532] = NetworkConfig("Base Sepolia", 84532, true);

        // Optimism
        networkConfigs[10] = NetworkConfig("Optimism Mainnet", 10, false);
        networkConfigs[11155420] = NetworkConfig("Optimism Sepolia", 11155420, true);

        // Arbitrum
        networkConfigs[42161] = NetworkConfig("Arbitrum One", 42161, false);
        networkConfigs[421614] = NetworkConfig("Arbitrum Sepolia", 421614, true);

        // Polygon
        networkConfigs[137] = NetworkConfig("Polygon Mainnet", 137, false);
        networkConfigs[80001] = NetworkConfig("Mumbai Testnet", 80001, true);

        // Ethereum
        networkConfigs[1] = NetworkConfig("Ethereum Mainnet", 1, false);
        networkConfigs[11155111] = NetworkConfig("Sepolia Testnet", 11155111, true);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 chainId = block.chainid;

        NetworkConfig memory config = networkConfigs[chainId];

        console.log("===========================================");
        console.log("Deploying AdvertisementManager");
        console.log("===========================================");
        console.log("Network:", config.name);
        console.log("Chain ID:", chainId);
        console.log("Is Testnet:", config.isTestnet);
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("===========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy do contrato principal
        AdvertisementManager adManager = new AdvertisementManager();

        console.log("\n===========================================");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("===========================================");
        console.log("AdvertisementManager:", address(adManager));
        console.log("AdToken:", address(adManager.adToken()));
        console.log("===========================================");

        // Informações adicionais
        console.log("\nInitial Configuration:");
        console.log("- Initial Ad Price:", adManager.getNextAdPrice());
        console.log("- Price Multiplier: 1.05 (5%)");
        console.log("- Referral Discount: 10%");
        console.log("- Engagement Reward: 2 tokens");
        console.log("===========================================");

        // Salvar endereços em arquivo JSON
        _saveDeployment(chainId, address(adManager), address(adManager.adToken()));

        vm.stopBroadcast();

        // Instruções pós-deploy
        _printPostDeployInstructions(chainId, address(adManager));
    }

    function _saveDeployment(uint256 chainId, address adManager, address adToken) internal {
        string memory json = string(
            abi.encodePacked(
                "{\n",
                '  "chainId": ',
                vm.toString(chainId),
                ",\n",
                '  "network": "',
                networkConfigs[chainId].name,
                '",\n',
                '  "AdvertisementManager": "',
                vm.toString(adManager),
                '",\n',
                '  "AdToken": "',
                vm.toString(adToken),
                '",\n',
                '  "timestamp": ',
                vm.toString(block.timestamp),
                ",\n",
                '  "deployer": "',
                vm.toString(vm.addr(vm.envUint("PRIVATE_KEY"))),
                '"\n',
                "}"
            )
        );

        string memory filename =
            string(abi.encodePacked("deployments/", vm.toString(chainId), "-", vm.toString(block.timestamp), ".json"));

        vm.writeFile(filename, json);
        console.log("\nDeployment info saved to:", filename);
    }

    function _printPostDeployInstructions(uint256 chainId, address adManager) internal view {
        console.log("\n===========================================");
        console.log("POST-DEPLOYMENT INSTRUCTIONS");
        console.log("===========================================");

        NetworkConfig memory config = networkConfigs[chainId];

        console.log("\n1. Verify Contract:");
        console.log("   forge verify-contract", adManager);
        console.log("   --chain-id", chainId);
        console.log("   --watch");

        console.log("\n2. Add Initial Achievements:");
        console.log("   cast send", adManager);
        console.log("   'addAchievement(string,string,uint256,uint256)'");
        console.log("   'First Steps' 'Create your first ad' 1 100");

        console.log("\n3. Start First Community Challenge:");
        console.log("   cast send", adManager);
        console.log("   'startNewCommunityChallenge(string,uint256,uint256,uint256)'");
        console.log("   'Launch Challenge' 100 10000 604800");

        console.log("\n4. Configure Frontend:");
        console.log("   Update your .env file with:");
        console.log("   VITE_ADVERTISEMENT_MANAGER_ADDRESS=", adManager);
        console.log("   VITE_CHAIN_ID=", chainId);

        if (config.isTestnet) {
            console.log("\n5. Get Testnet Tokens:");
            _printFaucetInfo(chainId);
        }

        console.log("\n===========================================");
    }

    function _printFaucetInfo(uint256 chainId) internal pure {
        if (chainId == 44787) {
            // Celo Alfajores
            console.log("   Celo Faucet: https://faucet.celo.org");
        } else if (chainId == 534351) {
            // Scroll Sepolia
            console.log("   Scroll Faucet: https://sepolia.scroll.io/faucet");
        } else if (chainId == 84532) {
            // Base Sepolia
            console.log("   Base Faucet: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet");
        } else if (chainId == 11155420) {
            // Optimism Sepolia
            console.log("   Optimism Faucet: https://app.optimism.io/faucet");
        } else if (chainId == 421614) {
            // Arbitrum Sepolia
            console.log("   Arbitrum Faucet: https://faucet.quicknode.com/arbitrum/sepolia");
        } else if (chainId == 80001) {
            // Mumbai
            console.log("   Mumbai Faucet: https://faucet.polygon.technology/");
        } else if (chainId == 11155111) {
            // Sepolia
            console.log("   Sepolia Faucet: https://sepoliafaucet.com/");
        }
    }
}

/**
 * @title DeployToAllNetworks
 * @notice Script para deploy em todas as redes de uma vez (use com cuidado!)
 */
contract DeployToAllNetworks is Script {
    struct Deployment {
        string network;
        uint256 chainId;
        address adManager;
        address adToken;
    }

    Deployment[] public deployments;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("===========================================");
        console.log("MULTI-NETWORK DEPLOYMENT");
        console.log("===========================================");
        console.log("This will deploy to ALL configured networks");
        console.log("Make sure you have sufficient funds on all networks!");
        console.log("===========================================\n");

        // Array de RPCs (configure no .env)
        string[14] memory rpcKeys = [
            "CELO_RPC_URL",
            "CELO_ALFAJORES_RPC_URL",
            "SCROLL_RPC_URL",
            "SCROLL_SEPOLIA_RPC_URL",
            "BASE_RPC_URL",
            "BASE_SEPOLIA_RPC_URL",
            "OPTIMISM_RPC_URL",
            "OPTIMISM_SEPOLIA_RPC_URL",
            "ARBITRUM_RPC_URL",
            "ARBITRUM_SEPOLIA_RPC_URL",
            "POLYGON_RPC_URL",
            "MUMBAI_RPC_URL",
            "ETHEREUM_RPC_URL",
            "SEPOLIA_RPC_URL"
        ];

        for (uint256 i = 0; i < rpcKeys.length; i++) {
            try vm.envString(rpcKeys[i]) returns (string memory rpcUrl) {
                console.log("Deploying to", rpcKeys[i]);
                _deployToNetwork(rpcUrl, deployerPrivateKey);
            } catch {
                console.log("Skipping", rpcKeys[i], "(not configured)");
            }
        }

        // Salvar resumo de todos os deploys
        _saveAllDeployments();
    }

    function _deployToNetwork(string memory rpcUrl, uint256 privateKey) internal {
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(privateKey);
        AdvertisementManager adManager = new AdvertisementManager();
        vm.stopBroadcast();

        deployments.push(
            Deployment({
                network: _getNetworkName(block.chainid),
                chainId: block.chainid,
                adManager: address(adManager),
                adToken: address(adManager.adToken())
            })
        );

        console.log("  -> AdvertisementManager:", address(adManager));
        console.log("  -> AdToken:", address(adManager.adToken()));
        console.log("");
    }

    function _getNetworkName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 42220) return "Celo Mainnet";
        if (chainId == 44787) return "Celo Alfajores";
        if (chainId == 534352) return "Scroll Mainnet";
        if (chainId == 534351) return "Scroll Sepolia";
        if (chainId == 8453) return "Base Mainnet";
        if (chainId == 84532) return "Base Sepolia";
        if (chainId == 10) return "Optimism Mainnet";
        if (chainId == 11155420) return "Optimism Sepolia";
        if (chainId == 42161) return "Arbitrum One";
        if (chainId == 421614) return "Arbitrum Sepolia";
        if (chainId == 137) return "Polygon Mainnet";
        if (chainId == 80001) return "Mumbai Testnet";
        if (chainId == 1) return "Ethereum Mainnet";
        if (chainId == 11155111) return "Sepolia Testnet";
        return "Unknown";
    }

    function _saveAllDeployments() internal {
        console.log("\n===========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("===========================================\n");

        string memory json = "[\n";

        for (uint256 i = 0; i < deployments.length; i++) {
            Deployment memory d = deployments[i];

            console.log("Network:", d.network);
            console.log("Chain ID:", d.chainId);
            console.log("AdvertisementManager:", d.adManager);
            console.log("AdToken:", d.adToken);
            console.log("");

            json = string(
                abi.encodePacked(
                    json,
                    "  {\n",
                    '    "network": "',
                    d.network,
                    '",\n',
                    '    "chainId": ',
                    vm.toString(d.chainId),
                    ",\n",
                    '    "AdvertisementManager": "',
                    vm.toString(d.adManager),
                    '",\n',
                    '    "AdToken": "',
                    vm.toString(d.adToken),
                    '"\n',
                    "  }",
                    i < deployments.length - 1 ? ",\n" : "\n"
                )
            );
        }

        json = string(abi.encodePacked(json, "]"));

        vm.writeFile("deployments/all-networks.json", json);
        console.log("Summary saved to: deployments/all-networks.json");
    }
}
