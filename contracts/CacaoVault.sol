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
        uint256 _duration,
        address _lender
    ) external returns (uint256) {
        require(msg.sender == cacao, "Not owner");
        IERC721(_collection).transferFrom(_lender, address(this), _tokenId);
        Offer memory newOffer = tokenIdToOffer[_collection][_tokenId];
        _mint(_lender, tokenCounter);
        IDelegationRegistry(delegationRegistry).delegateForToken(
            _lender,
            _collection,
            _tokenId,
            true
        );

        uint256 utilityToken = tokenCounter;
        newOffer.lender = _lender;
        newOffer.duration = _duration;
        newOffer.utilityTokenId = tokenCounter++;

        return utilityToken;
    }

    function transferFrom(address to, uint256 tokenId) public {
        Offer memory offer = utilityTokenToOffer[tokenId];
        address owner = ERC721.ownerOf(tokenId);
        ERC721.transferFrom(owner, to, tokenId);
        IDelegationRegistry(delegationRegistry).delegateForToken(
            owner,
            offer.collection,
            tokenId,
            false
        );
        IDelegationRegistry(delegationRegistry).delegateForToken(
            to,
            offer.collection,
            tokenId,
            true
        );
    }

    function transferDelegate(
        address from,
        address to,
        address collection,
        uint256 tokenId
    ) public {}

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
        require(msg.sender == offer.lender || msg.sender == cacao, "Not owner");
        IERC721(collection).safeTransferFrom(
            address(this),
            ownerAddress,
            tokenId
        );
    }
}
