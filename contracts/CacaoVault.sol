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

    mapping(uint256 => Offer) utilityTokenToOffer;

    // NFT collection address => tokenID => offerID
    // mapping(address => mapping(uint256 => uint256)) tokenToOfferId;

    struct Offer {
        address lender;
        uint256 duration;
        address collection;
        uint256 tokenId;
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
    function depositToVault(Offer memory offer) external {
        require(msg.sender == cacao, "Not owner");
        IERC721(offer.collection).transferFrom(
            offer.lender,
            address(this),
            offer.tokenId
        );
        Offer memory newOffer = tokenIdToOffer[offer.collection][offer.tokenId];
        newOffer.lender = offer.lender;
        newOffer.duration = offer.duration;
        _mint(offer.lender, tokenCounter);
    }

    function transferFrom(address to, uint256 tokenId) public override {
        bool value = true;
        super.transferFrom(msg.sender, to, tokenId);
        Offer memory offer = utilityTokenToOffer[tokenId];
        IDelegationRegistry(delegationRegistry).delegateForToken(
            to,
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
