// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {LinearCurve} from "./LinearCurve.sol";

library LinearCurveSpread {
    using FixedPointMathLib for uint256;
    using LinearCurve for LinearCurve.Params;

    /// @notice WAD-scaled curve parameters
    struct Params {
        LinearCurve.Params p;
        uint128 buySpread;
        uint128 sellSpread;
    }

    function reserveInForTokenOut(Params memory P, uint256 supply, uint256 tokenOut)
        internal
        pure
        returns (uint256 reserveIn)
    {
        uint256 baseReserveIn = P.p.reserveInForTokenOut(supply, tokenOut);

        reserveIn = baseReserveIn.mulWadUp(FixedPointMathLib.WAD + P.buySpread);
    }

    function reserveOutForTokenIn(Params memory P, uint256 supply, uint256 tokenIn)
        internal
        pure
        returns (uint256 reserveOut)
    {
        uint256 baseReserveOut = P.p.reserveOutForTokenIn(supply, tokenIn);

        reserveOut = baseReserveOut.mulWad(FixedPointMathLib.WAD - P.sellSpread);
    }
}
