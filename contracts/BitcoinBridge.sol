// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title BitcoinBridge
 * @author Prime AI
 * @notice Hybrid bridge allowing Bitcoin holders to participate in PrimeCrypto ecosystem
 * @dev Accepts wrapped Bitcoin (WBTC) and swaps for PRIME at market rate
 * 
 * This enables:
 * - Bitcoin holders to enter the PRIME ecosystem
 * - Value conversion from BTC to ethical currency
 * - Hybrid flexibility while maintaining PRIME principles
 * 
 * NOTE: This is a simplified bridge. Production would use:
 * - Chainlink price feeds for BTC/PRIME rate
 * - Multi-sig custody for WBTC
 * - Cross-chain messaging (LayerZero, CCIP)
 */
contract BitcoinBridge is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // ============ Constants ============
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant RATE_SETTER_ROLE = keccak256("RATE_SETTER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_FEE_BPS = 500; // 5% max fee
    
    // ============ State Variables ============
    
    IERC20 public immutable wbtc;       // Wrapped Bitcoin address
    IERC20 public immutable primeToken; // PRIME token address
    
    uint256 public exchangeRate;        // WBTC to PRIME rate (scaled by 1e18)
    uint256 public feeBps;              // Fee in basis points (100 = 1%)
    
    uint256 public totalWbtcReceived;
    uint256 public totalPrimeDistributed;
    uint256 public totalFeeCollected;
    
    bool public acceptingDeposits = true;
    
    // Sustainability: track for carbon offset calculation
    uint256 public btcTransactionsCount;
    
    // ============ Events ============
    
    event Swapped(
        address indexed user,
        uint256 wbtcAmount,
        uint256 primeAmount,
        uint256 feeAmount,
        uint256 exchangeRate
    );
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event DepositsToggled(bool accepting);
    event LiquidityAdded(uint256 primeAmount);
    event LiquidityRemoved(uint256 primeAmount);
    
    // ============ Errors ============
    
    error DepositsDisabled();
    error InsufficientLiquidity();
    error InvalidAmount();
    error InvalidRate();
    error FeeTooHigh();
    
    // ============ Constructor ============
    
    /**
     * @notice Deploy the Bitcoin Bridge
     * @param _wbtc Address of Wrapped Bitcoin contract
     * @param _primeToken Address of PRIME token contract
     * @param _admin Admin address
     * @param _initialRate Initial exchange rate (PRIME per WBTC, scaled by 1e18)
     */
    constructor(
        address _wbtc,
        address _primeToken,
        address _admin,
        uint256 _initialRate
    ) {
        require(_wbtc != address(0), "Invalid WBTC");
        require(_primeToken != address(0), "Invalid PRIME");
        require(_initialRate > 0, "Invalid rate");
        
        wbtc = IERC20(_wbtc);
        primeToken = IERC20(_primeToken);
        exchangeRate = _initialRate;
        feeBps = 50; // 0.5% default fee
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
        _grantRole(RATE_SETTER_ROLE, _admin);
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Swap WBTC for PRIME tokens
     * @param wbtcAmount Amount of WBTC to swap (8 decimals)
     * @return primeAmount Amount of PRIME received
     * 
     * The conversion represents a philosophical transition:
     * Bitcoin (store of value) → PRIME (ethical utility)
     */
    function swapBtcToPrime(uint256 wbtcAmount) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 primeAmount) 
    {
        if (!acceptingDeposits) revert DepositsDisabled();
        if (wbtcAmount == 0) revert InvalidAmount();
        
        // Calculate PRIME amount (WBTC is 8 decimals, PRIME is 18)
        // Rate is PRIME per WBTC, so we multiply
        uint256 grossPrime = (wbtcAmount * exchangeRate) / 1e8; // Adjust for decimal difference
        
        // Calculate fee
        uint256 fee = (grossPrime * feeBps) / 10000;
        primeAmount = grossPrime - fee;
        
        // Check liquidity
        if (primeToken.balanceOf(address(this)) < primeAmount) {
            revert InsufficientLiquidity();
        }
        
        // Transfer WBTC in
        wbtc.safeTransferFrom(msg.sender, address(this), wbtcAmount);
        
        // Transfer PRIME out
        primeToken.safeTransfer(msg.sender, primeAmount);
        
        // Update stats
        totalWbtcReceived += wbtcAmount;
        totalPrimeDistributed += primeAmount;
        totalFeeCollected += fee;
        btcTransactionsCount++;
        
        emit Swapped(msg.sender, wbtcAmount, primeAmount, fee, exchangeRate);
        
        return primeAmount;
    }
    
    /**
     * @notice Get quote for WBTC to PRIME swap
     * @param wbtcAmount Amount of WBTC
     * @return primeAmount Estimated PRIME output
     * @return feeAmount Fee that will be charged
     */
    function getQuote(uint256 wbtcAmount) 
        external 
        view 
        returns (uint256 primeAmount, uint256 feeAmount) 
    {
        uint256 grossPrime = (wbtcAmount * exchangeRate) / 1e8;
        feeAmount = (grossPrime * feeBps) / 10000;
        primeAmount = grossPrime - feeAmount;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update exchange rate
     * @param newRate New rate (PRIME per WBTC, scaled by 1e18)
     * 
     * In production, this would be automated via Chainlink oracle
     */
    function setExchangeRate(uint256 newRate) 
        external 
        onlyRole(RATE_SETTER_ROLE) 
    {
        if (newRate == 0) revert InvalidRate();
        
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        
        emit ExchangeRateUpdated(oldRate, newRate);
    }
    
    /**
     * @notice Update swap fee
     * @param newFeeBps New fee in basis points
     */
    function setFee(uint256 newFeeBps) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        
        uint256 oldFee = feeBps;
        feeBps = newFeeBps;
        
        emit FeeUpdated(oldFee, newFeeBps);
    }
    
    /**
     * @notice Add PRIME liquidity for swaps
     * @param amount Amount of PRIME to add
     */
    function addLiquidity(uint256 amount) 
        external 
        onlyRole(OPERATOR_ROLE) 
    {
        primeToken.safeTransferFrom(msg.sender, address(this), amount);
        emit LiquidityAdded(amount);
    }
    
    /**
     * @notice Remove PRIME liquidity
     * @param amount Amount to remove
     * @param to Recipient address
     */
    function removeLiquidity(uint256 amount, address to) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        primeToken.safeTransfer(to, amount);
        emit LiquidityRemoved(amount);
    }
    
    /**
     * @notice Withdraw collected WBTC
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawWbtc(address to, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        wbtc.safeTransfer(to, amount);
    }
    
    /**
     * @notice Toggle deposit acceptance
     */
    function toggleDeposits() external onlyRole(OPERATOR_ROLE) {
        acceptingDeposits = !acceptingDeposits;
        emit DepositsToggled(acceptingDeposits);
    }
    
    /**
     * @notice Pause contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get available PRIME liquidity
     */
    function availableLiquidity() external view returns (uint256) {
        return primeToken.balanceOf(address(this));
    }
    
    /**
     * @notice Get WBTC balance held
     */
    function wbtcBalance() external view returns (uint256) {
        return wbtc.balanceOf(address(this));
    }
    
    /**
     * @notice Get bridge statistics
     */
    function getStats() external view returns (
        uint256 _totalWbtcReceived,
        uint256 _totalPrimeDistributed,
        uint256 _totalFeeCollected,
        uint256 _btcTransactionsCount,
        uint256 _currentRate,
        uint256 _currentFee
    ) {
        return (
            totalWbtcReceived,
            totalPrimeDistributed,
            totalFeeCollected,
            btcTransactionsCount,
            exchangeRate,
            feeBps
        );
    }
    
    /**
     * @notice Estimate carbon footprint contribution
     * @dev Used for sustainability reporting
     * Average BTC transaction: ~400 kg CO2
     * This bridge helps transition to lower-carbon PRIME
     */
    function estimatedCarbonSaved() external view returns (uint256 kgCO2) {
        // Each BTC transaction on main chain ~400kg CO2
        // PRIME on Base L2 ~0.01kg CO2
        // Net savings per transaction: ~399.99kg
        return btcTransactionsCount * 400;
    }
}
