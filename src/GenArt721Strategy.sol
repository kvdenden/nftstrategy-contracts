// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {NFTStrategy} from "./NFTStrategy.sol";

interface IGenArt721 {
    function tokenIdToProjectId(uint256 tokenId) external view returns (uint256);
}

contract GenArt721Strategy is NFTStrategy {
    uint256 public projectId;

    /// @param _token The address of the strategy token contract.
    /// @param _nft The address of the NFT contract.
    /// @param _projectId The artblocks project ID.
    constructor(address _token, address _nft, uint256 _projectId)
        NFTStrategy(_token, _nft, 0.01 ether)
    {
        projectId = _projectId;
    }

    function _validateBuyNFT(uint256, uint256 tokenId) internal view override {
        require(
            IGenArt721(address(nft)).tokenIdToProjectId(tokenId) == projectId, "Invalid project ID"
        );
    }
}
