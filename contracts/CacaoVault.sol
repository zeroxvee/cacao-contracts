// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IDelegationRegistry.sol";

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

    address public delegationRegistry;
    address private cacao;
    uint256 tokenCounter;

    // NFT collection address => tokenID => Owner address
    mapping(address => mapping(uint256 => Offer)) tokenIdToOffer;

    // NFT collection address => tokenID => offerID
    // mapping(address => mapping(uint256 => uint256)) tokenToOfferId;

    struct Offer {
        address lender;
        uint256 duration;
        uint256 collection;
        uint256 utilityTokenId;
    }

    function setMarketplaceAddress(address _cacao) external {
        cacao = _cacao;
    }

    /*
     *   depositing NFT asset and minting new NFT-U token
     *   NFT-U holder has all the right and utilies that come with NFT assest deposited
     *   and the check will be happending thru delegate.cash
     */
    function depositToVault(
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

    function transferFrom(address to, uint256 tokenId) public override {
        bool value = true;
        IDelegationRegistry(delegationRegistry).delegateForToken(
            msg.sender,
            _collection,
            _tokenId,
            value
        );
        super.transferFrom(from, to, tokenId);
    }

    /*
     *   When called by NFT asset owner => burns NFT-U token,
     *   removes any delegation records,
     *   returns NFT assest to the owner
     */
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
