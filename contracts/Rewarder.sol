//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";


contract Rewarder is Initializable, OwnableUpgradeable {

    mapping(address => uint256) public available;
    mapping(address => uint256) public claimed;

    IERC20Upgradeable public xtc;
    uint256 public rate;  // in bps
    address public game;

    event RateUpdated(uint256 rate);
    event GameUpdated(address indexed game);
    event RewardTokenSet(address indexed token);

    function initialize (uint256 _rate, address _game) public initializer{
        rate = _rate;
        game = _game;
        __Ownable_init();
    }

    function setToken(IERC20Upgradeable _token) external onlyOwner {
        require(address(_token) != address(0), "Reward token can't be 0 address");
        xtc = _token;
        emit RewardTokenSet(address(_token));
    }

    function claim() external {
        uint256 _claimable = available[msg.sender] - claimed[msg.sender];
        claimed[msg.sender] += _claimable;
        require(xtc.transfer(msg.sender, _claimable), "failed to send");
    }

    function claimable(address user) external view returns (uint256) {
        return available[user] - claimed[user];
    }

    function addReward(address user, uint256 betAmount) external {
        require(msg.sender == game, "Caller not game");
        available[user] += betAmount * rate / 10000;
    }

    function addRewardAdjusted(address user, uint256 betAmount, uint64 rollId) external {
        require(msg.sender == game, "Caller not game");
        // We want to change weight based on how long until
        // the roll starts. We have a maximum and a minimum.
        // time => 10 mins == max reward
        // time == 0 mins == no reward.
        uint256 adjustedRate;
        if (rollId < block.timestamp) {
            adjustedRate = rate;
            /// XXX Just return here.
        } else {
            uint256 minsUntilStart = (rollId - block.timestamp) / 60;
            if (minsUntilStart > 10) {
                adjustedRate = rate;
            } else {
                adjustedRate = rate * minsUntilStart / 10;
            }
        }
        available[user] += betAmount * adjustedRate / 10000;
    }

    function rewardableAmount(uint256 betAmount, uint64 rollId) external view returns (uint256) {
       uint256 adjustedRate;
        if (rollId < block.timestamp) {
            adjustedRate = rate;
        } else {
            uint256 minsUntilStart = (rollId - block.timestamp) / 60;
            if (minsUntilStart >= 10) {
                adjustedRate = rate;
            } else {
                adjustedRate = rate * minsUntilStart / 10;
            }
        }
        return betAmount * adjustedRate / 10000;
    }

    /// @notice Remove all incentive tokens from this contract.
    function sweep() external onlyOwner {
        require(xtc.transfer(msg.sender, xtc.balanceOf(address(this))), "failed to sweep");
    }

    function updateRate(uint256 _newRate) external onlyOwner {
        rate = _newRate;
        emit RateUpdated(_newRate);
    }

    function updateGame(address _game) external onlyOwner {
        game = _game;
        emit GameUpdated(_game);
    }

}
