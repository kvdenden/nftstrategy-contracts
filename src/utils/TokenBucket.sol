// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

abstract contract TokenBucket {
    using SafeCastLib for uint256;

    struct Bucket {
        uint256 capacity;
        uint128 tokens;
        uint64 lastUpdate;
        uint64 refillRate;
    }

    Bucket public bucket;

    event TokenBucketUpdated(uint256 capacity, uint256 tokens);
    event TokensConsumed(uint256 amount);

    constructor(uint256 capacity, uint256 refillRate) {
        bucket = Bucket({
            capacity: capacity,
            tokens: 0,
            lastUpdate: block.number.toUint64(),
            refillRate: refillRate.toUint64()
        });
    }

    /// @dev Returns the available tokens in the bucket.
    function _availableTokens() internal view returns (uint256) {
        Bucket memory b = bucket;
        return _availableTokens(b);
    }

    function _capacity() internal view returns (uint256) {
        return bucket.capacity;
    }

    function _lastUpdate() internal view returns (uint256) {
        return bucket.lastUpdate;
    }

    function _refillRate() internal view returns (uint256) {
        return bucket.refillRate;
    }

    function _isFull() internal view returns (bool) {
        return _availableTokens() == _capacity();
    }

    /// @dev Consumes the given amount of tokens from the bucket.
    function _consumeTokens(uint256 amount) internal {
        Bucket memory b = bucket;
        uint256 tokens = _availableTokens(b);
        require(amount <= tokens, "Insufficient available tokens");

        b.tokens = (tokens - amount).toUint128();
        b.lastUpdate = block.number.toUint64();
        bucket = b;

        emit TokensConsumed(amount);
    }

    /// @dev Updates bucket state.
    function _sync(uint256 newCapacity) internal {
        Bucket memory b = bucket;
        uint256 tokens = _availableTokens(b);

        b.capacity = newCapacity;
        b.tokens = tokens > newCapacity ? newCapacity.toUint128() : tokens.toUint128();
        b.lastUpdate = block.number.toUint64();
        bucket = b;

        emit TokenBucketUpdated(newCapacity, tokens);
    }

    function _availableTokens(Bucket memory b) internal view virtual returns (uint256) {
        uint256 capacity = b.capacity;

        uint256 elapsed = block.number - b.lastUpdate;
        uint256 tokens = b.tokens + elapsed * b.refillRate;

        return tokens > capacity ? capacity : tokens;
    }
}
