// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract MockStrategyToken is ERC20 {
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function name() public pure override returns (string memory) {
        return "MockStrategyToken";
    }

    function symbol() public pure override returns (string memory) {
        return "MST";
    }

    receive() external payable {}

    function mint(uint256 amount, address receiver) external payable {
        _mint(receiver, amount);
    }

    function surplus() public view returns (uint256) {
        return address(this).balance;
    }

    function useSurplus(uint256 amount) external {
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function lockedSupply() public view returns (uint256) {
        return balanceOf(DEAD_ADDRESS);
    }

    function effectiveSupply() public view returns (uint256) {
        return totalSupply() - lockedSupply();
    }

    function lock(uint256 amount, address from) external {
        if (msg.sender != from) {
            _spendAllowance(from, msg.sender, amount);
        }

        _transfer(from, DEAD_ADDRESS, amount);
    }
}
