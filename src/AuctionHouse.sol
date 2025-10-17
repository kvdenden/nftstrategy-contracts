// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

abstract contract AuctionHouse is ReentrancyGuard {
    event AuctionStarted(
        uint256 indexed auctionId, uint256 indexed tokenId, uint256 startPrice, uint256 decayRate
    );
    event AuctionSettled(
        uint256 indexed auctionId, uint256 indexed tokenId, address indexed buyer, uint256 price
    );

    Auction public auction;

    uint256 private _nextAuctionId;

    struct Auction {
        bool active;
        uint256 auctionId;
        uint256 tokenId;
        uint256 startTime;
        uint256 startPrice;
        uint256 decayRate;
    }

    modifier whenAuctionActive() {
        require(auction.active, "Auction not active");
        _;
    }

    modifier whenAuctionNotActive() {
        require(!auction.active, "Auction already active");
        _;
    }

    function startAuction(uint256 tokenId)
        external
        nonReentrant
        whenAuctionNotActive
        returns (uint256 auctionId)
    {
        (bool ready,) = _nextAuctionReady();
        require(ready, "Next auction not ready");

        _prepareAuction(tokenId);

        uint256 startPrice = _auctionStartPrice();
        uint256 decayRate = _auctionDecayRate();

        auctionId = _nextAuctionId++;
        auction = Auction({
            active: true,
            auctionId: auctionId,
            tokenId: tokenId,
            startTime: block.timestamp,
            startPrice: startPrice,
            decayRate: decayRate
        });

        emit AuctionStarted(auctionId, tokenId, startPrice, decayRate);
    }

    function take(uint256 maxPrice) external nonReentrant whenAuctionActive {
        uint256 price = currentAuctionPrice();
        require(price <= maxPrice, "Price too high");

        auction.active = false;
        uint256 tokenId = auction.tokenId;
        uint256 auctionId = auction.auctionId;
        _settleAuction(tokenId, msg.sender, price);
        emit AuctionSettled(auctionId, tokenId, msg.sender, price);
    }

    function currentAuction() external view returns (Auction memory) {
        return auction;
    }

    function isAuctionActive() external view returns (bool) {
        return auction.active;
    }

    function nextAuctionReady() external view returns (bool ready, uint256 waitTime) {
        return _nextAuctionReady();
    }

    function currentAuctionPrice() public view returns (uint256) {
        Auction memory auction_ = auction;
        if (!auction_.active) return 0;

        uint256 t = block.timestamp - auction_.startTime;
        return _priceAt(t, auction_.startPrice, auction_.decayRate);
    }

    function _priceAt(uint256 t, uint256 startPrice, uint256 decayRate)
        internal
        pure
        returns (uint256 price)
    {
        int256 exp = -int256(decayRate) * int256(t); // forge-lint: disable-line(unsafe-typecast)
        uint256 ratio = uint256(FixedPointMathLib.expWad(exp)); // forge-lint: disable-line(unsafe-typecast)

        if (ratio == 0) return 1;

        price = FixedPointMathLib.mulWadUp(startPrice, ratio);
    }

    function _prepareAuction(uint256 tokenId) internal virtual;
    function _settleAuction(uint256 tokenId, address buyer, uint256 price) internal virtual;

    function _nextAuctionReady() internal view virtual returns (bool ready, uint256 waitTime) {
        ready = true;
        waitTime = 0;
    }

    function _auctionStartPrice() internal view virtual returns (uint256) {
        return 21_000_000 * 1e17;
    }

    function _auctionDecayRate() internal view virtual returns (uint256) {
        return 1e14;
    }
}
