//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


interface IExotic{

    struct Bet {
        uint256 amount;
        address account;
        uint64 rollId;
        uint8 prediction;
        bool paid;
    }

    struct Roll {
        uint256 result;
        uint256 requestId;
    }

    function endRoll(uint256 requestId, uint256[] memory randomWords) external;
    function userBetCount(address userId) external view returns (uint256);
    function userRollBetCount(uint256 rollId, address user) external view returns (uint256);
    function roll(uint64 rollId) external view returns (Roll memory);
    function frequency() external view returns (uint256);
    function userBet(address user, uint256 betId) external view returns (Bet memory);
    function rollResult(uint64 rollId) external view returns (uint256);
    function totalWagered(uint64 rollId) external view returns (uint256);
    function odds(uint64 rollId, uint8 result) external view returns (uint256);
    function userRollBet(
        uint64 rollId, address user, uint256 betId
    ) external view returns (
        Bet memory
    );
}
