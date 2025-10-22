// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SmartContractWallet.sol";

contract SmartContractWalletFactory {

    event WalletCreated(address indexed wallet, address indexed owner);

    address private immutable _entryPoint;

    constructor(address entryPoint) {
        _entryPoint = entryPoint;
    }

    function createWallet(address owner, bytes32 salt) external returns (address wallet) {
        bytes memory bytecode = getWalletBytecode(owner);
        // Deploy using CREATE2
        assembly {
            wallet := create2(0, add(bytecode, 32), mload(bytecode), salt)
            if iszero(wallet) { revert(0, 0) }
        }
        emit WalletCreated(wallet, owner);
    }

    function getWalletAddress(address owner, bytes32 salt) external view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(getWalletBytecode(owner))
            )
        );
        return address(uint160(uint256(hash)));
    }

    function getWalletBytecode(address owner) internal view returns (bytes memory) {
        return abi.encodePacked(
            type(SmartContractWallet).creationCode,
            abi.encode(owner, _entryPoint)
        );
    }
}