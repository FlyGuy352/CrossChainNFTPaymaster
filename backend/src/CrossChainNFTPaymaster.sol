// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PaymasterCore, PackedUserOperation} from "@openzeppelin/community-contracts/account/paymaster/PaymasterCore.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract CrossChainNFTPaymaster is PaymasterCore, Ownable {

    error ParseFailed();
    error AdminSignatureFailed();
    error UserSignatureFailed();

    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address private immutable _admin;

    mapping(address user => mapping(uint256 tokenId => uint256 nonce)) public nonces;

    constructor(address owner, address admin) Ownable(owner) {
        _admin = admin;
    }

    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) internal override returns (bytes memory context, uint256 validationData) {
        (bytes memory adminSignature, uint256 tokenId, address userAddress, bytes memory userSignature) = extractData(userOp.paymasterAndData);
        bytes32 adminHash = keccak256(abi.encodePacked(tokenId, userAddress));
        if (adminHash.toEthSignedMessageHash().recover(adminSignature) != _admin) {
            revert AdminSignatureFailed();
        }
        uint256 currentNonce = nonces[userAddress][tokenId];
        bytes32 userHash = keccak256(abi.encodePacked(address(this), currentNonce));
        if (userHash.toEthSignedMessageHash().recover(userSignature) != userAddress) {
            revert UserSignatureFailed();
        }
        nonces[userAddress][tokenId]++;
        return ("", 0);
    }

    function extractData(bytes memory data) internal pure returns (
        bytes memory adminSignature,
        uint256 tokenId,
        address userAddress,
        bytes memory userSignature
    ) {
        if (data.length != 234) {
            revert ParseFailed();
        }

        adminSignature = new bytes(65);
        userSignature = new bytes(65);
        uint256 paymasterDataOffset = 52;
        
        assembly {
            let dataPtr := add(data, 32)
            let adminSignaturePtr := add(adminSignature, 32)
            let userSignaturePtr := add(userSignature, 32)

            {
                let src := add(dataPtr, paymasterDataOffset)
                let dest := adminSignaturePtr
                let len := 65
                for { let i := 0 } lt(i, len) { i := add(i, 32) } {
                    mstore(dest, mload(src))
                    src := add(src, 32)
                    dest := add(dest, 32)
                }
            }

            tokenId := mload(add(dataPtr, 117))
            userAddress := mload(add(dataPtr, 137))

            {
                let src := add(dataPtr, 169)
                let dest := userSignaturePtr
                let len := 65
                for { let i := 0 } lt(i, len) { i := add(i, 32) } {
                    mstore(dest, mload(src))
                    src := add(src, 32)
                    dest := add(dest, 32)
                }
            }
        }
    }
}