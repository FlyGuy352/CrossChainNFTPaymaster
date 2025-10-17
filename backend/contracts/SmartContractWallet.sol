// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Account} from "@openzeppelin/contracts/account/Account.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SmartContractWallet is Account {

    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    
    address private immutable _owner;

    constructor(address owner) {
        _owner = owner;
    }

    function execute(address dest, uint256 value, bytes calldata func) external onlyEntryPointOrSelf {
        _call(dest, value, func);
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _rawSignatureValidation(
        bytes32 hash,
        bytes calldata signature
    ) internal view override returns (bool) {
        address recovered = hash.toEthSignedMessageHash().recover(signature);
        return recovered == _owner;
    }
}