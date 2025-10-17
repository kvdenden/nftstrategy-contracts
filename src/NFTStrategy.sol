// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "solady/tokens/ERC721.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Receiver} from "solady/accounts/Receiver.sol";

import {IStrategyToken} from "./interfaces/IStrategyToken.sol";

import {AuctionHouse} from "./AuctionHouse.sol";
import {TokenBucket} from "./utils/TokenBucket.sol";

contract NFTStrategy is AuctionHouse, TokenBucket, Receiver {
    IStrategyToken public token;
    ERC721 public nft;

    uint256 public constant SYNC_REWARD_BPS = 50; // 0.5%
    uint256 public constant SYNC_THRESHOLD = 0.1 ether;

    error NotNFTOwner();

    event NFTBought(uint256 indexed tokenId, uint256 price);

    event RewardPaid(address indexed recipient, uint256 reward);

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
        require(target != address(nft), "Invalid target");

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

    function surplus() external view returns (uint256) {
        return _capacity();
    }

    function availableSurplus() external view returns (uint256) {
        return _availableTokens();
    }

    function syncSurplus() external nonReentrant {
        uint256 capacity = _capacity();
        uint256 newCapacity = token.surplus();
        if (_isFull() && _lastUpdate() < block.number && newCapacity > capacity + SYNC_THRESHOLD) {
            uint256 reward = SYNC_REWARD_BPS * (newCapacity - capacity) / 10_000;
            token.useSurplus(reward);
            SafeTransferLib.safeTransferETH(msg.sender, reward);

            emit RewardPaid(msg.sender, reward);
        }

        _sync(token.surplus());
    }

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

        _sync(token.surplus());
    }
}
