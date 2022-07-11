//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Rewarder is Ownable {

    mapping(address => uint256) public available;
    mapping(address => uint256) public claimed;

    IERC20 public xtc;
    uint256 public rate;  // in bps
    address public game;

    event RateUpdated(uint256 rate);
    event GameUpdated(address indexed game);
    event RewardTokenSet(address indexed token);

    constructor(uint256 _rate, address _game) {
        rate = _rate;
        game = _game;
    }

    function setToken(IERC20 _token) external onlyOwner {
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

    function addRewardAdjusted(address user, uint256 betAmount, uint64 raceId) external {
        require(msg.sender == game, "Caller not game");
        // We want to change weight based on how long until
        // the roll starts. We have a maximum and a minimum.
        // time => 10 mins == max reward
        // time == 0 mins == no reward.
        uint256 adjustedRate;
        if (raceId > block.timestamp) {
            adjustedRate = 0;
        } else {
            uint256 minsUntilStart = (block.timestamp - raceId) / 60;
            if (minsUntilStart > 10) {
                adjustedRate = rate;
            } else {
                adjustedRate = rate / (10 - minsUntilStart);
            }
        }
        available[user] += betAmount * rate / 10000;
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
