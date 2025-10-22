// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {HederaTokenService} from "@hashgraph/smart-contracts/contracts/system-contracts/hedera-token-service/HederaTokenService.sol";
import {IHederaTokenService} from "@hashgraph/smart-contracts/contracts/system-contracts/hedera-token-service/IHederaTokenService.sol";
import {HederaResponseCodes} from "@hashgraph/smart-contracts/contracts/system-contracts/HederaResponseCodes.sol";
import {KeyHelper} from "@hashgraph/smart-contracts/contracts/system-contracts/hedera-token-service/KeyHelper.sol";

contract HederaHybridNFT is HederaTokenService, KeyHelper, Ownable {

    error TokenAlreadyCreated(address tokenAddress);
    error TokenCreationFailed(int responseCode);
    error TokenNotDeployed();
    error SignatureFailed(bytes receivedSignature, bytes32 hash, bytes32 ethSignedMessageHash, address recoveredAddress);
    error MintFailed(int responseCode, uint256 serialsLength);

    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public tokenAddress;
    uint256 public latestTokenId;
    mapping(uint256 tokenId => bytes signature) public signatures;

    address private immutable _admin;

    event NFTCollectionCreated(address indexed token);
    event NFTMinted(address indexed to, uint256 indexed tokenId);

    constructor(address admin) Ownable(msg.sender) {
        _admin = admin;
    }

    function createNFTCollection(string memory name, string memory symbol) external payable onlyOwner {
        if (tokenAddress != address(0)) {
            revert TokenAlreadyCreated(tokenAddress);
        }

        IHederaTokenService.HederaToken memory token;
        token.name = name;
        token.symbol = symbol;
        token.treasury = address(this);
        token.memo = "";

        IHederaTokenService.TokenKey[] memory keys = new IHederaTokenService.TokenKey[](2);
        keys[0] = getSingleKey(KeyType.SUPPLY, KeyValueType.CONTRACT_ID, address(this));
        keys[1] = getSingleKey(KeyType.ADMIN, KeyValueType.CONTRACT_ID, address(this));
        token.tokenKeys = keys;

        (int responseCode, address created) = createNonFungibleToken(token);
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert TokenCreationFailed(responseCode);
        }
        tokenAddress = created;

        emit NFTCollectionCreated(created);
    }

    function mint(address owner, string memory tokenURI, bytes memory signature)
        external
        returns (uint256)
    {
        if (tokenAddress == address(0)) {
            revert TokenNotDeployed();
        }
        uint256 newTokenId = latestTokenId + 1;
        _verifySignature(owner, newTokenId, signature);

        bytes memory metadata = bytes(tokenURI);
        _mintAndSend(owner, metadata);

        signatures[newTokenId] = signature;

        latestTokenId++;
        return newTokenId;
    }

    function _verifySignature(address owner, uint256 tokenId, bytes memory signature) internal view {
        bytes32 hash = keccak256(abi.encodePacked(tokenId, owner));
        address recovered = hash.toEthSignedMessageHash().recover(signature);
        if (recovered != _admin) {
            revert SignatureFailed(signature, hash, hash.toEthSignedMessageHash(), recovered);
        }
    }

    function _mintAndSend(
        address to,
        bytes memory metadata
    ) private returns (uint256 tokenId) {
        // 1) Mint to treasury (this contract)
        bytes[] memory arr = new bytes[](1);
        arr[0] = metadata;
        (int responseCode, , int64[] memory serials) = mintToken(
            tokenAddress,
            0,
            arr
        );
        if (responseCode != HederaResponseCodes.SUCCESS || serials.length != 1) {
            revert MintFailed(responseCode, serials.length);
        }

        // 2) Transfer from treasury -> recipient via ERC721 facade
        uint256 serial = uint256(uint64(serials[0]));
        // Recipient must be associated (or have auto-association available)
        IERC721(tokenAddress).transferFrom(address(this), to, serial);

        emit NFTMinted(to, serial);
        return serial;
    }
}