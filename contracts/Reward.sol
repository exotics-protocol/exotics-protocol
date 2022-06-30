//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";

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

    constructor(IERC20 _xtc, uint256 _rate, address _game) {
        xtc = _xtc;
        rate = _rate;
        game = _game;
    }

    function claim() external {
        uint256 claimable = available[msg.sender] - claimed[msg.sender];
        claimed[msg.sender] += claimable;
        require(xtc.transfer(msg.sender, claimable), "failed to send");
    }

    function claimable(address user) external view returns (uint256) {
        return available[user] - claimed[user];
    }

    function addReward(address user, uint256 betAmount) external {
        require(msg.sender == game, "Caller not game");
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
