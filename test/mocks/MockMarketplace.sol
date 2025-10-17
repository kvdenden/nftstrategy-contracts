// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "solady/tokens/ERC721.sol";
import {Receiver} from "solady/accounts/Receiver.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract MockMarketplace is Receiver, ReentrancyGuard {
    ERC721 public immutable NFT;

    struct Listing {
        uint256 tokenId;
        uint256 price;
        address payable seller;
    }
    mapping(uint256 => Listing) public listings;

    constructor(address _nft) {
        NFT = ERC721(_nft);
    }

    function buy(uint256 tokenId) external payable nonReentrant {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "Listing not found");

        require(listing.tokenId == tokenId, "Invalid token ID");
        require(listing.price == msg.value, "Invalid price");

        listings[tokenId] = Listing({tokenId: tokenId, price: 0, seller: payable(address(0))});

        NFT.safeTransferFrom(address(this), msg.sender, listing.tokenId);
        SafeTransferLib.safeTransferETH(listing.seller, listing.price);
    }

    function notBuy(uint256 tokenId) external payable nonReentrant {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "Listing not found");

        require(listing.tokenId == tokenId, "Invalid token ID");
        require(listing.price == msg.value, "Invalid price");

        listings[tokenId] = Listing({tokenId: tokenId, price: 0, seller: payable(address(0))});

        // nft.safeTransferFrom(address(this), msg.sender, listing.tokenId);
        SafeTransferLib.safeTransferETH(listing.seller, listing.price);
    }

    function list(uint256 tokenId, uint256 price) external {
        listings[tokenId] = Listing({tokenId: tokenId, price: price, seller: payable(msg.sender)});
        NFT.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    function cancel(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "Listing not found");
        require(listing.seller == msg.sender, "Not the seller");

        listings[tokenId] = Listing({tokenId: tokenId, price: 0, seller: payable(address(0))});
        NFT.safeTransferFrom(address(this), msg.sender, tokenId);
    }
}
