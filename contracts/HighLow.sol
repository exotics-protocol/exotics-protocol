//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interfaces/IRewarder.sol";


/// @title An betting game with exotic bet types
contract HighLow is Initializable, OwnableUpgradeable, PausableUpgradeable {

    /// @notice the length of each roll (eg 1 week).
    uint64 public period;
    /// @notice how long the period lasts where no positions can be opened.
    uint64 public closePeriod;

    /// @notice Fee paramaters.
    uint256 public revenueFee;  // House take in bps
    uint256 public polFee;  // pol contribution in bps
    address public revenueAddress;  // Staking address
    address public polAddress;  // House POL address
    uint256 public maxBet;  // The maximum size a position can be opened for

    /// @notice Whether a market is open for a given symbol.
    mapping(address => bool) public enabledToken;
    /// @notice The address of oracle for a given symbol.
    mapping(address => address) public oracleAddress;

    /// @notice historic record of prices for a symbol
    /// tokenAddress => (timestamp => price);
    mapping(address => mapping(uint256 => uint256)) private price;

    /// @notice enum representing which side of a trader a user takes.
    enum Side { LOWER, HIGHER }
    struct Position {
        uint256 amount;
        address account;
        uint64 roundId;
        Side side;
        bool paid;
        uint64 timestamp;
        uint256 entryPrice;
    }

    struct Round {
        uint256 lowerPool;  // total amount wagered on lower.
        uint256 higherPool;  // total amount wagered on higher.
        uint256 sharesLower;  // Adjusted total share weight of lower positions.
        uint256 sharesHigher; // Adjusted total share weight of higher positions.
    }

    function initialize(
        uint256 _revenueFee,
        uint256 _polFee,
        address _revenueAddress,
        address _polAddress,
        uint256 _maxBet,
        uint64 _period,
        uint64 _closePeriod
    ) public initializer {
        revenueFee = _revenueFee;
        polFee = _polFee;
        revenueAddress = _revenueAddress;
        polAddress = _polAddress;
        maxBet = _maxBet;
        period = _period;
        closePeriod = _closePeriod;
        __Ownable_init();
        __Pausable_init();
    }

    function open(
        uint64 roundId,
        address token,
        Choice side
    ) external payable whenNotPaused returns (uint256 positionId) {
        require(roundId % period == 0, "Not valid round");
        require(roundId <= block.timestamp - closePeriod, "Cannot bet in close period");

        Round storage roll[token] = roll[rollId];

    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

}
