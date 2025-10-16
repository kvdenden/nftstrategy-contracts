// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "solady/tokens/ERC721.sol";

import {IStrategyToken} from "./interfaces/IStrategyToken.sol";

import {AuctionHouse} from "./AuctionHouse.sol";
import {TokenBucket} from "./utils/TokenBucket.sol";

contract NFTStrategy is AuctionHouse, TokenBucket {
    IStrategyToken public token;
    ERC721 public nft;

    error NotNFTOwner();

    event NFTBought(uint256 indexed tokenId, uint256 price);

    /// @param _token The address of the strategy token contract.
    /// @param _nft The address of the NFT contract.
    /// @param _buyIncrement The increment at which the token bucket is refilled.
    constructor(address _token, address _nft, uint256 _buyIncrement) TokenBucket(0, _buyIncrement) {
        require(_buyIncrement > 0, "Buy increment must be > 0");

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

        uint256 balance = address(this).balance;

        // pull needed funds from token contract
        if (balance < value) {
            uint256 needed = value - balance;
            _useSurplus(needed);
        }

        // Buy the nft
        (bool success,) = target.call{value: value}(data);
        require(success, "External call failed");
        require(nft.ownerOf(tokenId) == address(this), "Not NFT owner");

        emit NFTBought(tokenId, value);
    }

    function availableSurplus() external view returns (uint256) {
        return _availableTokens();
    }

    function syncSurplus() external {
        // TODO: add incentive/reward for syncing surplus
        _sync();
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

    function _useSurplus(uint256 amount) internal {
        _consumeTokens(amount);
        token.useSurplus(amount);
        _sync();
    }

    function _currentCapacity() internal view override returns (uint256) {
        return token.surplus();
    }
}
