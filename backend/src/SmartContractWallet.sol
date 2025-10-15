// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Account} from "@openzeppelin/contracts/account/Account.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SmartContractWallet is Account {

    using ECDSA for bytes32;
    address private immutable _owner;

    constructor(address owner) {
        _owner = owner;
    }

    function _rawSignatureValidation(
        bytes32 hash,
        bytes calldata signature
    ) internal view override returns (bool) {
        address recovered = ECDSA.recover(hash, signature);
        return recovered == _owner;
    }
}
