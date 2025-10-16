// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CreatorTokenBase} from "@limitbreak/creator-token-standards/utils/CreatorTokenBase.sol";
import {TOKEN_TYPE_ERC20} from "@limitbreak/permit-c/Constants.sol";

import {StrategyToken} from "./StrategyToken.sol";

contract StrategyAppToken is StrategyToken, CreatorTokenBase {
    constructor(uint128 _k, address _feeRecipient) StrategyToken(_k, _feeRecipient) {}

    function getTransferValidationFunction()
        external
        pure
        returns (bytes4 functionSignature, bool isViewFunction)
    {
        functionSignature =
            bytes4(keccak256("validateTransfer(address,address,address,uint256,uint256)"));
        isViewFunction = false;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        virtual
        override
    {
        _validateBeforeTransfer(from, to, 0, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        virtual
        override
    {
        _validateAfterTransfer(from, to, 0, amount);
    }

    function _tokenType() internal pure override returns (uint16) {
        return uint16(TOKEN_TYPE_ERC20); // forge-lint: disable-line(unsafe-typecast)
    }

    function _requireCallerIsContractOwner() internal view virtual override {
        require(msg.sender == owner(), "Caller is not the contract owner");
    }
}
