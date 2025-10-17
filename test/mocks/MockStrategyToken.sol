// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract MockStrategyToken is ERC20 {
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant MINT_PRICE = 0.01 ether;

    function name() public pure override returns (string memory) {
        return "MockStrategyToken";
    }

    function symbol() public pure override returns (string memory) {
        return "MST";
    }

    receive() external payable {}

    function previewMint(uint256 amount) external pure returns (uint256) {
        return _price(amount);
    }

    function mint(uint256 amount, address receiver) external payable {
        require(amount > 0, "Amount must be > 0");

        uint256 price = _price(amount);
        require(msg.value >= price, "Insufficient ETH");

        _mint(receiver, amount);
        SafeTransferLib.safeTransferETH(msg.sender, msg.value - price); // refund the remaining ETH
    }

    function previewRedeem(uint256 amount) external pure returns (uint256) {
        return _price(amount);
    }

    function redeem(uint256 amount, address from, address receiver, uint256 minAmountOut)
        external
        payable
    {
        require(amount > 0, "Amount must be > 0");

        uint256 price = _price(amount);
        require(price >= minAmountOut, "Insufficient output amount");

        _burn(from, amount);
        SafeTransferLib.safeTransferETH(receiver, price);
    }

    function surplus() public view returns (uint256) {
        return address(this).balance;
    }

    function useSurplus(uint256 amount) external {
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function maxSupply() public pure returns (uint256) {
        return 21_000_000 * 1e18;
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

    function _price(uint256 amount) internal pure returns (uint256) {
        return amount * MINT_PRICE / 1e18;
    }
}
