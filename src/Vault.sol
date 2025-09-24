// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/utils/Pausable.sol";

/**
 * @title Vault
 * @notice A vault contract that accepts ERC20 deposits and issues shares
 */
contract Vault is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    // ============ Events ============
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event EmergencyWithdraw(address indexed user, uint256 assets);

    // ============ Errors ============
    error ZeroAmount();
    error ZeroShares();
    error InsufficientBalance();
    error InsufficientShares();
    error InvalidFeeRate();
    error TransferFailed();
    error Unauthorized();

    // ============ State Variables ============
    IERC20 public immutable asset;

    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    uint256 public totalAssets;

    // Fee system
    uint256 public feeRate; // Basis points (100 = 1%)
    uint256 public constant MAX_FEE_RATE = 1000; // 10%
    uint256 public accumulatedFees;

    // Vault parameters
    uint256 public constant MINIMUM_SHARES = 1000; // Prevent donation attacks
    uint256 public lastUpdateTimestamp;

    // Emergency controls
    bool public emergencyMode;

    // ============ Constructor ============
    constructor(
        address _asset,
        uint256 _initialFeeRate,
        address _initialOwner
    ) Ownable(_initialOwner){
        if (_asset == address(0)) revert TransferFailed();
        if (_initialFeeRate > MAX_FEE_RATE) revert InvalidFeeRate();

        asset = IERC20(_asset);
        feeRate = _initialFeeRate;
        lastUpdateTimestamp = block.timestamp;

        // _transferOwnership(_initialOwner);
    }

    // ============ View Functions ============

    /**
     * @notice Convert assets to shares
     * @param assets Amount of assets to convert
     * @return shares Equivalent shares amount
     */
    function convertToShares(
        uint256 assets
    ) public view returns (uint256 shares) {
        if (totalSupply == 0) {
            return assets;
        }
        return (assets * totalSupply) / totalAssets;
    }

    /**
     * @notice Convert shares to assets
     * @param shares Amount of shares to convert
     * @return assets Equivalent assets amount
     */
    function convertToAssets(
        uint256 shares
    ) public view returns (uint256 assets) {
        if (totalSupply == 0) {
            return shares;
        }
        return (shares * totalAssets) / totalSupply;
    }

    /**
     * @notice Get maximum withdrawable assets for a user
     * @param user User address
     * @return maxAssets Maximum assets that can be withdrawn
     */
    function maxWithdraw(address user) public view returns (uint256 maxAssets) {
        return convertToAssets(balanceOf[user]);
    }

    /**
     * @notice Preview deposit operation
     * @param assets Amount of assets to deposit
     * @return shares Shares that would be minted
     */
    function previewDeposit(
        uint256 assets
    ) public view returns (uint256 shares) {
        return convertToShares(assets);
    }

    /**
     * @notice Preview withdraw operation
     * @param assets Amount of assets to withdraw
     * @return shares Shares that would be burned
     */
    function previewWithdraw(
        uint256 assets
    ) public view returns (uint256 shares) {
        if (totalSupply == 0) return assets;
        return (assets * totalSupply + totalAssets - 1) / totalAssets; // Round up
    }

    /**
     * @notice Deposit assets into vault
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive shares
     * @return shares Amount of shares minted
     */
    function deposit(
        uint256 assets,
        address receiver
    ) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert TransferFailed();

        // Calculate shares to mint
        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroShares();

        // First deposit must meet minimum shares requirement
        if (totalSupply == 0 && shares < MINIMUM_SHARES) {
            revert InsufficientShares();
        }

        // Update state before external calls
        balanceOf[receiver] += shares;
        totalSupply += shares;
        totalAssets += assets;
        lastUpdateTimestamp = block.timestamp;

        // Transfer assets from user
        asset.safeTransferFrom(msg.sender, address(this), assets);

        emit Deposit(receiver, assets, shares);
    }

    /**
     * @notice Withdraw assets from vault
     * @param assets Amount of assets to withdraw
     * @param receiver Address to receive assets
     * @param owner Address that owns the shares
     * @return shares Amount of shares burned
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert TransferFailed();

        shares = previewWithdraw(assets);

        // Check authorization @audit note Don't do this in real contract find a better way to track owner of the shares
        if (msg.sender != owner) {
            revert Unauthorized();
        }

        if (balanceOf[owner] < shares) revert InsufficientShares();
        if (totalAssets < assets) revert InsufficientBalance();

        // Calculate and deduct fees
        uint256 fee = (assets * feeRate) / 10000;
        uint256 assetsAfterFee = assets - fee;

        // Update state before external calls
        balanceOf[owner] -= shares;
        totalSupply -= shares;
        totalAssets -= assets;
        accumulatedFees += fee;
        lastUpdateTimestamp = block.timestamp;

        // Transfer assets to receiver
        asset.safeTransfer(receiver, assetsAfterFee);

        emit Withdraw(receiver, assetsAfterFee, shares);
    }

    /**
     * @notice Redeem shares for assets
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive assets
     * @param owner Address that owns the shares
     * @return assets Amount of assets withdrawn
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external nonReentrant whenNotPaused returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();
        if (balanceOf[owner] < shares) revert InsufficientShares();

        assets = convertToAssets(shares);
        if (assets == 0) revert ZeroAmount();

        // Calculate fees
        uint256 fee = (assets * feeRate) / 10000;
        uint256 assetsAfterFee = assets - fee;

        // Update state
        balanceOf[owner] -= shares;
        totalSupply -= shares;
        totalAssets -= assets;
        accumulatedFees += fee;
        lastUpdateTimestamp = block.timestamp;

        // Transfer assets
        asset.safeTransfer(receiver, assetsAfterFee);

        emit Withdraw(receiver, assetsAfterFee, shares);
    }

    // ============ Owner Functions ============

    /**
     * @notice Update fee rate (only owner)
     * @param newFeeRate New fee rate in basis points
     */
    function setFeeRate(uint256 newFeeRate) external onlyOwner {
        if (newFeeRate > MAX_FEE_RATE) revert InvalidFeeRate();

        uint256 oldRate = feeRate;
        feeRate = newFeeRate;

        emit FeeRateUpdated(oldRate, newFeeRate);
    }

    /**
     * @notice Withdraw accumulated fees (only owner)
     */
    function withdrawFees() external onlyOwner {
        uint256 fees = accumulatedFees;
        if (fees == 0) revert ZeroAmount();

        accumulatedFees = 0;
        asset.safeTransfer(owner(), fees);

        emit FeesWithdrawn(owner(), fees);
    }

    /**
     * @notice Pause the contract (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Enable emergency mode (only owner)
     * @dev In emergency mode, users can withdraw their proportional share of assets
     */
    function enableEmergencyMode() external onlyOwner {
        emergencyMode = true;
    }

    // ============ Emergency Functions ============

    /**
     * @notice Emergency withdraw for users when emergency mode is enabled
     * @dev Users get their proportional share of remaining assets
     */
    function emergencyWithdraw() external nonReentrant {
        if (!emergencyMode) revert TransferFailed();

        uint256 userShares = balanceOf[msg.sender];
        if (userShares == 0) revert InsufficientShares();

        uint256 userAssets = convertToAssets(userShares);

        // Update state
        balanceOf[msg.sender] = 0;
        totalSupply -= userShares;
        totalAssets -= userAssets;

        // Transfer assets (no fees in emergency)
        asset.safeTransfer(msg.sender, userAssets);

        emit EmergencyWithdraw(msg.sender, userAssets);
    }

    // ============ Helper Functions for Testing ============

    /**
     * @notice Get current vault state for testing
     * @return Current total supply, total assets, and accumulated fees
     */
    function getVaultState() external view returns (uint256, uint256, uint256) {
        return (totalSupply, totalAssets, accumulatedFees);
    }

    /**
     * @notice Calculate current exchange rate (assets per share)
     * @return rate Exchange rate scaled by 1e18
     */
    function exchangeRate() external view returns (uint256 rate) {
        if (totalSupply == 0) return 1e18;
        return (totalAssets * 1e18) / totalSupply;
    }
}
