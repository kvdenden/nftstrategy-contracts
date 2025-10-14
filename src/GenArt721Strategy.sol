// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {NFTStrategy} from "./NFTStrategy.sol";

interface IGenArt721 {
    function tokenIdToProjectId(uint256 tokenId) external view returns (uint256);
}

contract GenArt721Strategy is NFTStrategy {
    uint256 public projectId;

    constructor(address _token, address _nft, uint256 _projectId) NFTStrategy(_token, _nft) {
        projectId = _projectId;
    }

    function _validateBuyNFT(uint256, uint256 tokenId) internal view override {
        require(
            IGenArt721(address(nft)).tokenIdToProjectId(tokenId) == projectId, "Invalid project ID"
        );
    }
}
