// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {NFTStrategy} from "../src/NFTStrategy.sol";

import {MockERC721} from "../src/tokens/mocks/MockERC721.sol";

import {MockMarketplace} from "./mocks/MockMarketplace.sol";
import {MockStrategyToken} from "./mocks/MockStrategyToken.sol";

contract NFTStrategyTest is Test {
    MockERC721 public nft;
    MockMarketplace public marketplace;

    MockStrategyToken public strategyToken;
    NFTStrategy public nftStrategy;

    function setUp() public {
        nft = new MockERC721();
        marketplace = new MockMarketplace(address(nft));

        strategyToken = new MockStrategyToken();
        nftStrategy = new NFTStrategy(address(strategyToken), address(nft), 0.01 ether);
    }

    function test_syncSurplus() public {
        _increaseStrategyTokenSurplus(0.05 ether);
        assertEq(strategyToken.surplus(), 0.05 ether);

        nftStrategy.syncSurplus();

        assertEq(nftStrategy.surplus(), 0.05 ether);
        assertEq(nftStrategy.availableSurplus(), 0);

        vm.roll(block.number + 1);
        assertEq(nftStrategy.availableSurplus(), 0.01 ether);

        _increaseStrategyTokenSurplus(0.05 ether);
        assertEq(strategyToken.surplus(), 0.1 ether);

        vm.roll(block.number + 5);
        assertEq(nftStrategy.availableSurplus(), 0.05 ether); // only fill to last synced capacity

        nftStrategy.syncSurplus();

        vm.roll(block.number + 1);
        assertEq(nftStrategy.availableSurplus(), 0.06 ether);
    }

    function test_syncSurplus_reward() public {
        _increaseStrategyTokenSurplus(0.05 ether);

        uint256 balanceBeforeSync = address(this).balance;
        nftStrategy.syncSurplus();
        assertEq(address(this).balance, balanceBeforeSync); // no reward (capacity increase below threshold)

        vm.roll(block.number + 1);
        _increaseStrategyTokenSurplus(0.2 ether);

        balanceBeforeSync = address(this).balance;
        nftStrategy.syncSurplus();
        assertEq(address(this).balance, balanceBeforeSync); // no reward (bucket not full)

        vm.roll(block.number + 25); // wait until bucket is full
        _increaseStrategyTokenSurplus(0.2 ether);

        balanceBeforeSync = address(this).balance;
        uint256 expectedReward = 0.001 ether; // 0.5% of 0.2 ether
        vm.expectEmit(address(nftStrategy));
        emit NFTStrategy.RewardPaid(address(this), expectedReward);
        nftStrategy.syncSurplus();
        assertEq(address(this).balance, balanceBeforeSync + expectedReward); // 0.5%reward paid
        assertEq(nftStrategy.surplus(), 0.45 ether - expectedReward);
    }

    function test_buyNFT() public {
        _increaseStrategyTokenSurplus(0.05 ether);
        _listNFT(42, 0.05 ether);

        nftStrategy.syncSurplus();

        vm.expectRevert();
        _buyNFT(42, 0.05 ether);

        vm.roll(block.number + 4);
        vm.expectRevert();
        _buyNFT(42, 0.05 ether);

        vm.roll(block.number + 1);
        _buyNFT(42, 0.05 ether); // should succeed
    }

    function test_notBuyNFT() public {
        _increaseStrategyTokenSurplus(0.05 ether);

        _listNFT(42, 0.05 ether);

        nftStrategy.syncSurplus();
        vm.roll(block.number + 5);

        vm.expectRevert();
        _notBuyNFT(42, 0.05 ether);
    }

    function test_startAuction() public {
        _increaseStrategyTokenSurplus(1 ether);
        _listNFT(42, 1 ether);

        nftStrategy.syncSurplus();
        vm.roll(block.number + 100); // wait until bucket is full

        _buyNFT(42, 1 ether);

        vm.warp(block.timestamp + 24 hours);
        nftStrategy.startAuction(42);

        assertEq(nftStrategy.currentAuctionPrice(), 200 * 1e18); // 2 * 1 ether / 0.01 ether
    }

    function _increaseStrategyTokenSurplus(uint256 amount) internal {
        (bool success,) = address(strategyToken).call{value: amount}("");
        assertTrue(success);
    }

    function _listNFT(uint256 tokenId, uint256 price) internal {
        nft.mint(address(this), tokenId);
        nft.approve(address(marketplace), tokenId);

        marketplace.list(tokenId, price);
    }

    function _buyNFT(uint256 tokenId, uint256 price) internal {
        nftStrategy.buyNFT(
            price,
            tokenId,
            address(marketplace),
            abi.encodeWithSelector(MockMarketplace.buy.selector, tokenId)
        );
    }

    function _notBuyNFT(uint256 tokenId, uint256 price) internal {
        nftStrategy.buyNFT(
            price,
            tokenId,
            address(marketplace),
            abi.encodeWithSelector(MockMarketplace.notBuy.selector, tokenId)
        );
    }

    receive() external payable {}
}
