// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";

contract MockERC721 is ERC721 {
    string private constant BASE_URI = "https://example.com/tokens/";

    function name() public pure override returns (string memory) {
        return "MockERC721";
    }

    function symbol() public pure override returns (string memory) {
        return "MOCK";
    }

    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        return string.concat(BASE_URI, LibString.toString(tokenId));
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
