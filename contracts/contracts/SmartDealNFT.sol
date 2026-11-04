// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/// @title SmartDealNFT
/// @notice ERC-721 for digital goods (images, packs, PDFs via tokenURI metadata).
/// @dev Anyone can mint to themselves. No Ownable admin that can seize tokens.
///      Seller must own (and approve) the NFT to list it on the Marketplace.
contract SmartDealNFT is ERC721URIStorage {
    uint256 private _nextTokenId = 1;

    error EmptyURI();

    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);

    constructor() ERC721("Smart Deal NFT", "SDNFT") {}

    /// @notice Mint a new NFT to the caller with metadata URI.
    /// @param uri Metadata URI (IPFS/HTTPS JSON describing the digital good).
    /// @return tokenId Newly minted token id.
    function mint(string calldata uri) external returns (uint256 tokenId) {
        if (bytes(uri).length == 0) revert EmptyURI();
        tokenId = _nextTokenId;
        unchecked {
            _nextTokenId = tokenId + 1;
        }
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
        emit NFTMinted(msg.sender, tokenId, uri);
    }

    /// @notice Next token id that will be assigned on mint.
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }
}
