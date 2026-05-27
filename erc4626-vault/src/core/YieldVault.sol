// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {ProofOfReserves} from "../zk/ProofOfReserves.sol";

contract YieldVault is ERC4626, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    error ZeroAddress();
    error ZeroAmount();
    error DepositLimitExceeded();
    error Paused();
    error NotPaused();

    uint256 public constant MAX_TOTAL_ASSETS = 10_000_000e6;
    uint256 public constant MANAGEMENT_FEE_BPS = 200;
    uint256 public constant PERFORMANCE_FEE_BPS = 1000;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    uint256 public lastFeeCollection;
    address public feeRecipient;
    IStrategy public strategy;
    bool public paused;
    ProofOfReserves public reserveOracle;

    event PausedStateChanged(address indexed by, bool isPaused);
    event StrategyUpdated(
        address indexed oldStrategy,
        address indexed newStrategy
    );
    event FeeRecipientUpdated(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    event Harvested(uint256 yieldEarned, uint256 feesCollected);

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _feeRecipient,
        address _owner
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        if (_feeRecipient == address(0) || _owner == address(0))
            revert ZeroAddress();

        feeRecipient = _feeRecipient;
        lastFeeCollection = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(EMERGENCY_ROLE, _owner);
    }

    function setReserveOracle(
        address _oracle
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_oracle == address(0)) revert ZeroAddress();
        reserveOracle = ProofOfReserves(_oracle);
    }

    function setStrategy(
        address _strategy
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_strategy == address(0)) revert ZeroAddress();
        emit StrategyUpdated(address(strategy), _strategy);
        strategy = IStrategy(_strategy);
    }

    function setFeeRecipient(
        address _newRecipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, _newRecipient);
        feeRecipient = _newRecipient;
    }

    function harvest()
        external
        onlyRole(KEEPER_ROLE)
        whenNotPaused
        returns (uint256 yieldEarned, uint256 feesCollected)
    {
        if (address(strategy) == address(0)) return (0, 0);

        uint256 assetsBefore = totalAssets();
        strategy.harvest();
        uint256 assetsAfter = totalAssets();

        if (assetsAfter <= assetsBefore) return (0, 0);

        yieldEarned = assetsAfter - assetsBefore;
        feesCollected = (yieldEarned * PERFORMANCE_FEE_BPS) / BPS_DENOMINATOR;

        if (feesCollected > 0) {
            uint256 feeShares = convertToShares(feesCollected);
            _mint(feeRecipient, feeShares);
        }

        emit Harvested(yieldEarned, feesCollected);
        return (yieldEarned, feesCollected);
    }

    function pause() external onlyRole(EMERGENCY_ROLE) whenNotPaused {
        paused = true;
        emit PausedStateChanged(msg.sender, true);
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        paused = false;
        emit PausedStateChanged(msg.sender, false);
    }

    function emergencyWithdrawFromStrategy()
        external
        onlyRole(EMERGENCY_ROLE)
        whenPaused
    {
        if (address(strategy) != address(0)) {
            strategy.emergencyWithdraw();
        }
    }

    function totalAssets() public view virtual override returns (uint256) {
        uint256 vaultBalance = IERC20(asset()).balanceOf(address(this));
        if (address(strategy) != address(0)) {
            return vaultBalance + strategy.totalAssets();
        }
        return vaultBalance;
    }

    function maxDeposit(
        address
    ) public view virtual override returns (uint256) {
        uint256 currentAssets = totalAssets();
        if (currentAssets >= MAX_TOTAL_ASSETS) return 0;
        return MAX_TOTAL_ASSETS - currentAssets;
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(
        uint256 shares,
        address receiver
    ) public virtual override whenNotPaused returns (uint256) {
        return super.mint(shares, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override whenNotPaused returns (uint256) {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override whenNotPaused returns (uint256) {
        return super.redeem(shares, receiver, owner);
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        super._deposit(caller, receiver, assets, shares);
        if (address(strategy) != address(0)) {
            uint256 vaultBalance = IERC20(asset()).balanceOf(address(this));
            uint256 deployAmount = (vaultBalance * 90) / 100;

            if (deployAmount > 0) {
                IERC20(asset()).forceApprove(address(strategy), deployAmount);
                strategy.deposit(deployAmount);
            }
        }
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        _collectManagementFees();

        if (address(reserveOracle) != address(0)) {
            uint256 currentTotal = totalAssets();
            if (assets > (currentTotal * 10) / 100) {
                if (!reserveOracle.isSolvent())
                    revert("YieldVault: ZK Proof Stale");
            }
        }

        uint256 vaultBalance = IERC20(asset()).balanceOf(address(this));

        if (vaultBalance < assets && address(strategy) != address(0)) {
            uint256 shortfall = assets - vaultBalance;
            strategy.withdraw(shortfall);
        }
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _collectManagementFees() internal {
        uint256 timeSinceLastCollection = block.timestamp - lastFeeCollection;
        if (timeSinceLastCollection == 0) return;

        uint256 feeAmount = (totalAssets() *
            MANAGEMENT_FEE_BPS *
            timeSinceLastCollection) / (BPS_DENOMINATOR * 365 days);

        if (feeAmount > 0) {
            uint256 feeShares = convertToShares(feeAmount);
            _mint(feeRecipient, feeShares);
        }

        lastFeeCollection = block.timestamp;
    }
}
