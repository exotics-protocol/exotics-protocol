//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


interface IExotic{

    struct Bet {
        uint64 raceId;
        uint256 amount;
        address account;
        uint8 prediction;
        bool paid;
    }

    struct Race {
        uint256 result;
        uint256 requestId;
        //uint256[6][3] weights;
    }

    function endRace(uint256 requestId, uint256[] memory randomWords) external;
    function userBetCount(address userId) external view returns (uint256);
    function race(uint64 raceId) external view returns (Race memory);
    function frequency() external view returns (uint256);
    function userBet(address user, uint256 betId) external view returns (Bet memory);
    function raceResult(uint64 raceId) external view returns (uint256[1] memory);
    function totalWagered(uint64 raceId) external view returns (uint256);
    function odds(uint64 raceId, uint8 result) external view returns (uint256);
}
