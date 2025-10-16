// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract TokenBucket {
    struct Bucket {
        uint256 capacity;
        uint128 tokens;
        uint64 lastUpdate;
        uint64 refillRate;
    }

    Bucket public bucket;

    constructor(uint256 _capacity, uint256 _refillRate) {
        bucket = Bucket({
            capacity: _capacity,
            tokens: 0,
            lastUpdate: uint64(block.timestamp),
            refillRate: uint64(_refillRate)
        });
    }

    /// @dev Returns the available tokens in the bucket.
    function _availableTokens() internal view returns (uint256) {
        Bucket memory b = bucket;
        return _availableTokens(b);
    }

    /// @dev Consumes the given amount of tokens from the bucket.
    function _consumeTokens(uint256 amount) internal {
        Bucket memory b = bucket;
        uint256 tokens = _availableTokens(b);
        require(amount <= tokens, "Insufficient available tokens");

        b.tokens = uint128(tokens - amount);
        b.lastUpdate = uint64(block.timestamp);
        bucket = b;
    }

    /// @dev Updates bucket state based on current capacity and available tokens.
    function _sync() internal {
        Bucket memory b = bucket;
        uint256 tokens = _availableTokens(b);
        uint256 capacity = _currentCapacity();

        b.capacity = capacity;
        b.tokens = tokens > capacity ? uint128(capacity) : uint128(tokens);
        b.lastUpdate = uint64(block.timestamp);
        bucket = b;
    }

    function _availableTokens(Bucket memory b) internal view virtual returns (uint256) {
        uint256 capacity = b.capacity;

        uint256 elapsed = block.timestamp - b.lastUpdate;
        uint256 tokens = b.tokens + elapsed * b.refillRate;

        return tokens > capacity ? capacity : tokens;
    }

    /// @dev Override to change bucket capacity dynamically
    function _currentCapacity() internal view virtual returns (uint256) {
        return bucket.capacity;
    }
}
