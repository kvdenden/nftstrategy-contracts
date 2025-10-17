// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IStrategyToken {
    // === SURPLUS MANAGEMENT ===
    function surplus() external view returns (uint256);
    function useSurplus(uint256 amount) external;

    // === TOKEN SUPPLY STATE ===
    function maxSupply() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function effectiveSupply() external view returns (uint256);
    function lockedSupply() external view returns (uint256);

    // === TOKEN CURVE ===
    function previewMint(uint256 amount) external view returns (uint256);
    function previewRedeem(uint256 amount) external view returns (uint256);

    function mint(uint256 amount, address receiver) external payable;
    function redeem(uint256 amount, address from, address receiver, uint256 minAmountOut)
        external
        payable;

    // === TOKEN LOCKING ===
    function lock(uint256 amount, address from) external;
}
