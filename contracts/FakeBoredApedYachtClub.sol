// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract FakeBoredApeYachtClub is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("FakeBoredApedYachtClub", "FBAYC") {}

    function _baseURI() internal pure override returns (string memory) {
        return
            "https://us-central1-bayc-metadata.cloudfunctions.net/api/tokens/";
    }

    function safeMint(uint256 amount, address to) public {
        uint256 tokenId = _tokenIdCounter.current();
        for (uint256 i = 0; i < amount; i++) {
            _tokenIdCounter.increment();
            _safeMint(to, tokenId);
        }
    }
}
