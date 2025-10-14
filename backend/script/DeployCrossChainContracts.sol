// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import 'forge-std/Script.sol';
import '../src/CrossChainNFTPaymaster.sol';
import '../src/SimpleCounter.sol';
import { SmartContractWallet } from '../src/SmartContractWallet.sol';

contract DeployCrossChainContracts is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint('ETHEREUM_SEPOLIA_PRIVATE_KEY_ADMIN');
        
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.envAddress('ETHEREUM_SEPOLIA_PUBLIC_KEY_ADMIN');

        SimpleCounter counter = new SimpleCounter();
        CrossChainNFTPaymaster paymaster = new CrossChainNFTPaymaster(deployerAddress, vm.envAddress('HEDERA_TESTNET_PUBLIC_KEY_ADMIN'));
        SmartContractWallet account = new SmartContractWallet(vm.envAddress('PUBLIC_KEY_USER'));

        console.log('Counter: ', address(counter));
        console.log('PayMaster: ', address(paymaster));
        console.log('Account: ', address(account));

        vm.stopBroadcast();
    }
}