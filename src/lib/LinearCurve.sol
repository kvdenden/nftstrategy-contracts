// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/// @notice Linear bonding curve helpers for mint/redeem style flows.
/// price(s) = p0 + k * s
library LinearCurve {
    using FixedPointMathLib for uint256;

    /// @notice WAD-scaled curve parameters
    struct Params {
        uint128 p0;
        uint128 k;
    }

    /// @notice Reserve required to mint `tokenOut`
    /// @dev reserveIn = p0 * tokenOut + k * tokenOut * (supply + tokenOut/2)
    /// @dev (round UP)
    function reserveInForTokenOut(Params memory P, uint256 supply, uint256 tokenOut)
        internal
        pure
        returns (uint256 reserveIn)
    {
        // Calculate the area under the curve from supply to (supply + tokenOut)
        // Formula: p0 * tokenOut + k * tokenOut * (supply + tokenOut/2)

        // First term: base price contribution
        uint256 basePrice = tokenOut.mulWadUp(P.p0);

        // Second term: slope contribution
        // Average supply during minting: supply + tokenOut/2
        uint256 averageSupply = supply + (tokenOut + 1) / 2;
        uint256 slopePrice = tokenOut.mulWadUp(averageSupply).mulWadUp(P.k);

        reserveIn = basePrice + slopePrice;
    }

    /// @notice Reserve received for burning `tokenIn`
    /// @dev reserveOut = p0 * tokenIn + k * tokenIn * (supply - tokenIn/2)
    /// @dev (round DOWN)
    function reserveOutForTokenIn(Params memory P, uint256 supply, uint256 tokenIn)
        internal
        pure
        returns (uint256 reserveOut)
    {
        // Calculate the area under the curve from (supply - tokenIn) to supply
        // Formula: p0 * tokenIn + k * tokenIn * (supply - tokenIn/2)

        // First term: base price contribution
        uint256 basePrice = tokenIn.mulWad(P.p0);

        // Second term: slope contribution
        // Average supply during burning: supply - tokenIn/2
        uint256 averageSupply = supply - tokenIn / 2;
        uint256 slopePrice = tokenIn.mulWad(averageSupply).mulWad(P.k);

        reserveOut = basePrice + slopePrice;
    }
}
