//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";



// The equity farm is where you can stake xtc tokens in exchange
// for a share of the protocol fees.

contract EquityFarm is Initializable, OwnableUpgradeable{
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 claimable;
    }
    mapping(address => UserInfo) public users;
    IERC20Upgradeable public xtc;
    uint256 public lastRewardBalance;
    uint256 public accRewardPerShare;
    uint256 private claimable;
    uint256 private constant PRECISION = 1e18;

    event RewardTokenSet(address indexed token);
    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event Claimed(address indexed account, uint256 amount);

    function initialize() public initializer{
        __Ownable_init();
    }

    function setToken(IERC20Upgradeable _token) external onlyOwner {
        require(address(_token) != address(0), "Reward token can't be 0 address");
        xtc = _token;
        emit RewardTokenSet(address(_token));
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
        emit Deposited(msg.sender, amount);
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
        emit Withdrawn(msg.sender, amount);
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
        emit Claimed(msg.sender, total);
        payable(msg.sender).transfer(total);
    }

    function updateReward() public {
        uint256 rewardBalance = address(this).balance - claimable;
        if (rewardBalance == lastRewardBalance) return;
        uint256 accrued = rewardBalance - lastRewardBalance;
        uint256 xtcBalance = xtc.balanceOf(address(this));
        if(xtcBalance == 0) return;
        accRewardPerShare += ((accrued * PRECISION) / xtcBalance);
        lastRewardBalance = rewardBalance;
    }
    fallback() external payable {}
    receive() external payable {}
}
