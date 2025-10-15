// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import 'forge-std/Script.sol';
import '../src/DummyNFT.sol';

contract DeployHedera is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint('HEDERA_TESTNET_PRIVATE_KEY_ADMIN');
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.envAddress('HEDERA_TESTNET_PUBLIC_KEY_ADMIN');
        DummyNFT nft = new DummyNFT(deployerAddress);
        console.log('NFT: ', address(nft));

        vm.stopBroadcast();
    }
}