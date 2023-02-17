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
    ) ERC721(_name, _symbol) {}

    address private cacao;

    // NFT collection address => tokenID => Owner address
    mapping(address => mapping(uint256 => address)) tokenIdToOwner;

    // NFT collection address => tokenID => offerID
    mapping(address => mapping(uint256 => uint256)) tokenToOfferId;

    function setCacaoAddress(address _cacao) external {
        cacao = _cacao;
    }
}
