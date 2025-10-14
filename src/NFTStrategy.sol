// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IStrategyToken} from "./interfaces/IStrategyToken.sol";

import {AuctionHouse} from "./AuctionHouse.sol";

import {ERC721} from "solady/tokens/ERC721.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract NFTStrategy is AuctionHouse {
    IStrategyToken public token;
    ERC721 public nft;

    uint256 public constant REWARD = 0.01 ether;

    error NotNFTOwner();

    event NFTBought(uint256 indexed tokenId, uint256 price);

    constructor(address _token, address _nft) {
        token = IStrategyToken(_token);
        nft = ERC721(_nft);
    }

    function buyNFT(uint256 value, uint256 tokenId, address target, bytes calldata data)
        external
        payable
        nonReentrant
    {
        // check if we're not the current owner
        require(nft.ownerOf(tokenId) != address(this), "Already NFT owner");
        _validateBuyNFT(value, tokenId); // extra validation logic

        // check if we have enough surplus

        // Calculate required ETH (nft price + reward)
        uint256 totalRequired = value + REWARD;
        uint256 balance = address(this).balance;

        // pull needed funds from token contract
        if (balance < totalRequired) {
            uint256 needed = totalRequired - balance;
            token.useSurplus(needed);
        }

        // Buy the nft
        (bool success,) = target.call{value: value}(data);
        require(success, "External call failed");
        require(nft.ownerOf(tokenId) == address(this), "Not NFT owner");

        emit NFTBought(tokenId, value);

        // pay reward to sender
        SafeTransferLib.safeTransferETH(msg.sender, REWARD);
    }

    receive() external payable {} // can receive ETH

    function _validateBuyNFT(uint256 value, uint256 tokenId) internal view virtual {} // extra nft purchase validation logic

    function _prepareAuction(uint256 tokenId) internal view override {
        require(nft.ownerOf(tokenId) == address(this), "Not NFT owner");
    }

    function _settleAuction(uint256 tokenId, address buyer, uint256 price) internal override {
        token.lock(price, buyer);
        nft.safeTransferFrom(address(this), buyer, tokenId);
    }
}
