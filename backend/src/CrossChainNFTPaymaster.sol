// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PaymasterCore, PackedUserOperation} from "@openzeppelin/community-contracts/account/paymaster/PaymasterCore.sol";

contract CrossChainNFTPaymaster is PaymasterCore, Ownable {
    function extractData(bytes memory data) internal pure returns (bytes memory adminSignature, uint256 tokenId, address userAddress, bytes memory userSignature) {
         if (data.length != 234) {
            revert ParseFailed();
        }
        
        adminSignature = new bytes(65);
        userSignature = new bytes(65);

        assembly {
            let dataPtr := add(data, 32)
            dataPtr := add(dataPtr, 52)
            mcopy(add(0x20, adminSignature), dataPtr, 65)
            tokenId := mload(add(dataPtr, 65))
            userAddress := mload(add(dataPtr, 85))
            mcopy(add(0x20, userSignature), add(dataPtr, 117), 65)
        }
    }
}