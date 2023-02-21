// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/*
 *   Automated contract that will hold Lenders NFT assets until withdrawned
 *
 */

contract CacaoVault is ERC721 {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        _mint(msg.sender, tokenCounter);
        tokenCounter++;
    }

    address private cacao;
    uint256 tokenCounter;

    // NFT collection address => tokenID => Owner address
    mapping(address => mapping(uint256 => Offer)) tokenIdToOffer;

    // NFT collection address => tokenID => offerID
    mapping(address => mapping(uint256 => uint256)) tokenToOfferId;

    struct Offer {
        address nftOwner;
        uint256 duration;
    }

    function setCacaoAddress(address _cacao) external {
        cacao = _cacao;
    }

    function depositNft(
        address _collection,
        uint256 _tokenId,
        address _owner,
        uint256 _duration
    ) external {
        address owner = IERC721(_collection).ownerOf(_tokenId);
        require(msg.sender == owner || msg.sender == cacao, "Not owner");
        IERC721(_collection).transferFrom(_owner, address(this), _tokenId);
        Offer memory newOffer = tokenIdToOffer[_collection][_tokenId];
        newOffer.nftOwner = _owner;
        newOffer.duration = _duration;
        _mint(_owner, tokenCounter);
    }

    function withdrawNft(
        address collection,
        uint256 tokenId,
        address ownerAddress
    ) external {
        Offer memory offer = tokenIdToOffer[collection][tokenId];
        require(
            msg.sender == offer.nftOwner || msg.sender == cacao,
            "Not owner"
        );
        IERC721(collection).safeTransferFrom(
            address(this),
            ownerAddress,
            tokenId
        );
    }
}
