//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "hardhat/console.sol";

// The equity farm is where you can stake xtc tokens in exchange
// for a share of the protocol fees.

contract EquityFarm {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 claimable;
    }
    mapping(address => UserInfo) public users;
    IERC20 public xtc;
    uint256 public lastRewardBalance;
    uint256 public accRewardPerShare;
    uint256 private claimable;
    uint256 private constant PRECISION = 1e18;

    constructor(IERC20 _xtc) {
        xtc = _xtc;
    }

    function deposit(uint256 amount) external {
        UserInfo storage user = users[msg.sender];
        updateReward();

        uint256 previousAmount = user.amount;
        user.amount += amount;

        uint256 previousRewardDebt = user.rewardDebt;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        uint256 pending = (previousAmount * accRewardPerShare) /
            PRECISION -
            previousRewardDebt;

        user.claimable += pending;
        claimable += pending;
        lastRewardBalance -= pending;

        xtc.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        UserInfo storage user = users[msg.sender];
        require(user.amount >= amount, "Invalid withdraw amount");
        updateReward();

        uint256 previousAmount = user.amount;
        user.amount -= amount;

        uint256 previousRewardDebt = user.rewardDebt;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        uint256 pending = (previousAmount * accRewardPerShare) /
            PRECISION -
            previousRewardDebt;

        user.claimable += pending;
        claimable += pending;
        lastRewardBalance -= pending;
        xtc.transfer(msg.sender, amount);
    }

    function pendingReward(address account) public view returns (uint256) {
        UserInfo storage user = users[account];
        uint256 _totalxtc = xtc.balanceOf(address(this));
        uint256 _accRewardPerShare = accRewardPerShare;
        uint256 _rewardBalance = address(this).balance - claimable;

        if (_rewardBalance != lastRewardBalance && _totalxtc != 0) {
            uint256 _accruedReward = _rewardBalance - lastRewardBalance;
            _accRewardPerShare =
                _accRewardPerShare +
                ((_accruedReward * PRECISION) / _totalxtc);
        }
        return
            (user.amount * _accRewardPerShare) /
            PRECISION -
            user.rewardDebt +
            user.claimable;
    }

    function claim() external {
        UserInfo storage user = users[msg.sender];
        updateReward();

        uint256 pending = (user.amount * accRewardPerShare) /
            PRECISION -
            user.rewardDebt;
        uint256 claiming = user.claimable;
        uint256 total = pending + claiming;

        claimable -= claiming;
        user.claimable = 0;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
        lastRewardBalance -= pending;
        payable(msg.sender).transfer(total);
    }

    function updateReward() public {
        uint256 rewardBalance = address(this).balance - claimable;
        if (rewardBalance == lastRewardBalance) return;
        uint256 accrued = rewardBalance - lastRewardBalance;
        accRewardPerShare += ((accrued * PRECISION) /
            xtc.balanceOf(address(this)));
        lastRewardBalance = rewardBalance;
    }

    fallback() external payable {}
}
