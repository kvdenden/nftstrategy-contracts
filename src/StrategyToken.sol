// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

import {ERC20} from "solady/tokens/ERC20.sol";
import {Pausable} from "./utils/Pausable.sol";
import {QuadraticCurve} from "./lib/QuadraticCurve.sol";
import {QuadraticCurveSpread} from "./lib/QuadraticCurveSpread.sol";

contract StrategyToken is ERC20, ReentrancyGuard, Pausable {
    using QuadraticCurve for QuadraticCurve.Params;
    using QuadraticCurveSpread for QuadraticCurveSpread.Params;

    QuadraticCurveSpread.Params public curve;

    uint256 public constant MAX_SUPPLY = 21_000_000 * 1e18;
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint128 public constant FEE_RATE = 1e17; // 10%
    uint256 public constant PROTOCOL_FEE_BPS = 2000; // 20% of fee rate
    address public protocolFeeRecipient;

    address public strategy;

    /// @dev Emitted during a mint call
    event Mint(address indexed by, address indexed to, uint256 assets, uint256 tokens);

    /// @dev Emitted during a redeem call.
    event Redeem(
        address indexed by, address indexed from, address indexed to, uint256 assets, uint256 tokens
    );

    /// @dev Emitted during a lock call
    event Lock(address indexed by, address indexed from, uint256 tokens);

    /// @dev Emitted when strategy is updated
    event StrategyUpdated(address indexed newStrategy);

    /// @dev Emitted when surplus is used by strategy
    event SurplusUsed(address indexed strategy, uint256 amount);

    /// @dev Marks a function as only callable by the strategy.
    modifier onlyStrategy() {
        require(msg.sender == strategy, "Only strategy");
        _;
    }

    constructor(uint128 _k, address _feeRecipient) {
        _initializeOwner(msg.sender); // Initialize owner to deployer

        require(_k > 0, "k must be > 0");

        protocolFeeRecipient = _feeRecipient;

        curve = QuadraticCurveSpread.Params({
            p: QuadraticCurve.Params({p0: 0, k: _k}),
            buySpread: FEE_RATE,
            sellSpread: FEE_RATE
        });
    }

    function name() public pure override returns (string memory) {
        return "Strategy Token";
    }

    function symbol() public pure override returns (string memory) {
        return "ST";
    }

    /// @dev Returns the collateral required to mint the given token amount.
    function previewMint(uint256 amount) external view returns (uint256) {
        return _mintPrice(totalSupply(), amount);
    }

    /// @dev Mints the given token amount to the receiver.
    function mint(uint256 amount, address receiver) external payable nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be > 0");

        uint256 supply = totalSupply();

        require(supply + amount <= MAX_SUPPLY, "Max supply reached");
        uint256 price = _mintPrice(supply, amount);
        require(msg.value >= price, "Insufficient ETH");

        uint256 protocolFee = _protocolFee(supply, amount);

        _mint(receiver, amount);
        emit Mint(msg.sender, receiver, price, amount);

        SafeTransferLib.safeTransferETH(protocolFeeRecipient, protocolFee);
        SafeTransferLib.safeTransferETH(msg.sender, msg.value - price); // refund the remaining ETH
    }

    /// @dev Returns the amount of collateral returned for the given token amount.
    function previewRedeem(uint256 amount) external view returns (uint256) {
        return _redeemPrice(totalSupply(), amount);
    }

    /// @dev Redeems the given token amount from the owner.
    function redeem(
        uint256 amount,
        address from,
        address receiver,
        uint256 minAmountOut // minimum collateral returned, needed for slippage protection
    ) external payable nonReentrant {
        require(amount > 0, "Amount must be > 0");

        uint256 supply = totalSupply();

        uint256 price = _redeemPrice(supply, amount);
        require(price >= minAmountOut, "Insufficient output amount");

        if (msg.sender != from) {
            _spendAllowance(from, msg.sender, amount);
        }

        _burn(from, amount);
        emit Redeem(msg.sender, from, receiver, price, amount);

        SafeTransferLib.safeTransferETH(receiver, price);
    }

    /// @dev Lock the given amount of tokens to the dead address.
    function lock(uint256 amount, address from) external {
        require(amount > 0, "Amount must be > 0");

        transferFrom(from, DEAD_ADDRESS, amount);
        emit Lock(msg.sender, from, amount);
    }

    /// @dev Returns the amount of tokens locked (sent to dead address)
    function lockedSupply() public view returns (uint256) {
        return balanceOf(DEAD_ADDRESS);
    }

    /// @dev Returns the effective supply (total supply minus locked tokens)
    function effectiveSupply() public view returns (uint256) {
        return totalSupply() - lockedSupply();
    }

    /// @dev Returns the ETH reserve required to back all redeemable tokens
    function reserve() public view returns (uint256) {
        return _redeemPrice(totalSupply(), effectiveSupply());
    }

    /// @dev Returns the surplus ETH available for strategy
    function surplus() public view returns (uint256) {
        uint256 balance = address(this).balance;

        uint256 supply = totalSupply();
        uint256 amount = effectiveSupply();

        uint256 reserve_ = _redeemPrice(supply, amount);

        uint256 base_ = curve.p.reserveOutForTokenIn(supply, amount);
        uint256 deferred_ = (base_ - reserve_) * (10000 - PROTOCOL_FEE_BPS) / 10000;

        return balance - reserve_ - deferred_;
    }

    /// @dev Sets the strategy contract address.
    /// @param newStrategy The new strategy contract address.
    function setStrategy(address newStrategy) external onlyOwner {
        strategy = newStrategy;
        emit StrategyUpdated(newStrategy);
    }

    /// @dev Sets the protocol fee recipient address.
    /// @param newRecipient The new protocol fee recipient address.
    function setProtocolFeeRecipient(address newRecipient) external onlyOwner {
        protocolFeeRecipient = newRecipient;
    }

    /// @dev Allows strategy to use surplus funds.
    /// @param amount The amount of surplus to use.
    function useSurplus(uint256 amount) external nonReentrant onlyStrategy {
        require(amount <= surplus(), "Insufficient surplus");
        SafeTransferLib.safeTransferETH(strategy, amount);
        emit SurplusUsed(strategy, amount);
    }

    receive() external payable {} // can receive ETH

    function _mintPrice(uint256 supply, uint256 amount) internal view returns (uint256) {
        require(supply + amount <= MAX_SUPPLY, "Max supply reached");
        return curve.reserveInForTokenOut(supply, amount);
    }

    function _redeemPrice(uint256 supply, uint256 amount) internal view returns (uint256) {
        require(supply >= amount, "Insufficient supply");
        return curve.reserveOutForTokenIn(supply, amount);
    }

    function _protocolFee(uint256 supply, uint256 amount) internal view returns (uint256) {
        uint256 mintPrice = _mintPrice(supply, amount);
        uint256 redeemPrice = _redeemPrice(supply + amount, amount);
        return (mintPrice - redeemPrice) * PROTOCOL_FEE_BPS / 10000;
    }
}
