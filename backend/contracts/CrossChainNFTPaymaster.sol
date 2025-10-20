// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC4337Utils} from "@openzeppelin/contracts/account/utils/draft-ERC4337Utils.sol";
import {IEntryPoint, IPaymaster, PackedUserOperation} from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";

abstract contract PaymasterCore is IPaymaster {
    error PaymasterUnauthorized(address sender);

    modifier onlyEntryPoint() {
        _checkEntryPoint();
        _;
    }

    modifier onlyWithdrawer() {
        _authorizeWithdraw();
        _;
    }

    function entryPoint() public view virtual returns (IEntryPoint) {
        return ERC4337Utils.ENTRYPOINT_V08;
    }

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) public virtual onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) public virtual onlyEntryPoint {
        _postOp(mode, context, actualGasCost, actualUserOpFeePerGas);
    }

    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPreFund
    ) internal virtual returns (bytes memory context, uint256 validationData);

    function _postOp(
        PostOpMode /* mode */,
        bytes calldata /* context */,
        uint256 /* actualGasCost */,
        uint256 /* actualUserOpFeePerGas */
    ) internal virtual {}

    function deposit() public payable virtual {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    function withdraw(address payable to, uint256 value) public virtual onlyWithdrawer {
        entryPoint().withdrawTo(to, value);
    }

    function addStake(uint32 unstakeDelaySec) public payable virtual {
        entryPoint().addStake{value: msg.value}(unstakeDelaySec);
    }

    function unlockStake() public virtual onlyWithdrawer {
        entryPoint().unlockStake();
    }

    function withdrawStake(address payable to) public virtual onlyWithdrawer {
        entryPoint().withdrawStake(to);
    }

    function _checkEntryPoint() internal view virtual {
        address sender = msg.sender;
        if (sender != address(entryPoint())) {
            revert PaymasterUnauthorized(sender);
        }
    }

    function _authorizeWithdraw() internal virtual;
}

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PackedUserOperation} from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
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
    address private immutable _entryPoint;

    mapping(address user => mapping(uint256 tokenId => uint256 nonce)) public nonces;

    constructor(address owner, address admin, address entryPoint) Ownable(owner) {
        _admin = admin;
        _entryPoint = entryPoint;
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

    // Ensures the caller is the authorized EntryPoint (defaults to canonical if none set); allows using a mock EntryPoint during testing and reverts if unauthorized
    function _checkEntryPoint() internal view override {
        address sender = msg.sender;
        if (
            (_entryPoint == address(0) && sender != address(entryPoint())) ||
            (_entryPoint != address(0) && sender != _entryPoint)
        ) {
            revert PaymasterUnauthorized(sender);
        }
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

    function _authorizeWithdraw() internal virtual override onlyOwner {}
}