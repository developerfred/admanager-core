// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/AdvertisementManager.sol";

contract DeployAdvertisementManager is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AdvertisementManager adManager = new AdvertisementManager();
        console.log("AdvertisementManager deployed at:", address(adManager));

        vm.stopBroadcast();
    }
}