// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MockERC721} from "./MockERC721.sol";

contract MockGenArt721 is MockERC721 {
    function tokenIdToProjectId(uint256 tokenId) public pure returns (uint256) {
        return tokenId / 1000;
    }
}
