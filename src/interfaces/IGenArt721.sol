// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IGenArt721 {
    function tokenIdToProjectId(uint256 tokenId) external view returns (uint256);
}
