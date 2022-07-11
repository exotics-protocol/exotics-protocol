//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


interface IRewarder{
    function claim() external;
    function claimable(address userId) external view returns (uint256);
    function addReward(address userId, uint256 betAmount) external;
    function addRewardAdjusted(address user, uint256 betAmount, uint64 raceId) external;
}
