// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract DummyNFT is ERC721URIStorage {

    error SignatureFailed(bytes receivedSignature, bytes32 hash, bytes32 ethSignedMessageHash, address recoveredAddress);

    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 public latestTokenId;
    mapping(uint256 tokenId => bytes signature) public signatures;
    
    address private immutable _admin;

    constructor(address admin) ERC721("DummyNFT", "NFT") {
        _admin = admin;
    }

    function mint(address owner, string memory tokenURI, bytes memory signature)
        public
        returns (uint256)
    {
        uint256 newTokenId = latestTokenId + 1;
        bytes32 hash = keccak256(abi.encodePacked(newTokenId, owner));
        address recovered = hash.toEthSignedMessageHash().recover(signature);
        if (recovered != _admin) {
            revert SignatureFailed(signature, hash, hash.toEthSignedMessageHash(), recovered);
        }
        
        _mint(owner, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        signatures[newTokenId] = signature;

        latestTokenId++;
        return newTokenId;
    }
}