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
        string memory _symbol,
        address _delegationRegistry
    ) ERC721(_name, _symbol) {
        delegationRegistry = _delegationRegistry;
        _mint(msg.sender, 0);
    }

    address public delegationRegistry;
    address private cacao;
    uint256 tokenCounter = 1;

    // NFT collection address => tokenID => Owner address
    // mapping(address => mapping(uint256 => Offer)) tokenIdToOffer;

    mapping(uint256 => Offer) utilityTokenToOffer;

    // NFT collection address => tokenID => offerID
    // mapping(address => mapping(uint256 => uint256)) tokenToOfferId;

    struct Offer {
        address lender;
        uint256 duration;
        address collection;
        uint256 tokenId;
    }

    function setMarketplaceAddress(address _cacao) external {
        cacao = _cacao;
        ERC721.setApprovalForAll(_cacao, true);
    }

    /*
     *   depositing NFT asset and minting new NFT-U token
     *   NFT-U holder has all the right and utilies that come with NFT assest deposited
     *   and the check will be happending thru delegate.cash
     */
    function depositToVault(
        address _collection,
        uint256 _tokenId,
        uint256 _expiration,
        address _lender
    ) external returns (uint256) {
        require(msg.sender == cacao, "Not owner");
        ERC721(_collection).transferFrom(_lender, address(this), _tokenId);
        _mint(_lender, tokenCounter);
        IDelegationRegistry(delegationRegistry).delegateForToken(
            _lender,
            _collection,
            _tokenId,
            true
        );

        Offer storage newOffer = utilityTokenToOffer[tokenCounter];
        newOffer.lender = _lender;
        newOffer.collection = _collection;
        newOffer.tokenId = _tokenId;
        newOffer.duration = _expiration;

        uint256 utilityToken = tokenCounter++;

        return utilityToken;
    }

    function transferFrom(
        address from,
        address to,
        uint256 utilityTokenId
    ) public override {
        Offer memory offer = utilityTokenToOffer[utilityTokenId];
        // delegation rights for lended NFT
        IDelegationRegistry(delegationRegistry).delegateForToken(
            from,
            offer.collection,
            offer.tokenId,
            false
        );
        IDelegationRegistry(delegationRegistry).delegateForToken(
            to,
            offer.collection,
            offer.tokenId,
            true
        );
        ERC721.transferFrom(from, to, utilityTokenId);
    }

    /*
     *   When called by NFT asset owner => burns NFT-U token,
     *   removes any delegation records,
     *   returns NFT assest to the owner
     */
    function withdrawNft(uint256 utilityTokenId) external {
        Offer memory offer = utilityTokenToOffer[utilityTokenId];
        require(msg.sender == offer.lender || msg.sender == cacao, "Not owner");
        ERC721(offer.collection).safeTransferFrom(
            address(this),
            offer.lender,
            offer.tokenId
        );
    }
}
