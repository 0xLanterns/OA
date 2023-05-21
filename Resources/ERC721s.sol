// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "../lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";

contract MyERC721 is ERC721 {
    // using Counters for Counters.Counter;

    // Counters.Counter private _tokenIdTracker;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    // function mint(address to) external returns (uint256) {
    //     _tokenIdTracker.increment();
    //     uint256 newTokenId = _tokenIdTracker.current();
    //     _safeMint(to, newTokenId);
    //     return newTokenId;
    // }
        /// @notice mint a token
    /// @param to who to mint the token to
    /// @param tokenId the token ID to mint
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

