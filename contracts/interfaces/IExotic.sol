//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


interface IExotic{

    struct Bet {
        uint256 raceId;
        uint256 amount;
        address account;
        uint256[] place;
        bool paid;
    }

    struct Race {
        uint256 paid;
        uint256 result;
        uint256 requestId;
        //uint256[6][3] weights;
    }

    function endRace(uint256 requestId, uint256[] memory randomWords) external;
    function userBetCount(address userId) external view returns (uint256);
    function race(uint256 raceId) external view returns (Race memory);
    function frequency() external view returns (uint256);
    function userBet(address user, uint256 betId) external view returns (Bet memory);
    function raceResult(uint256 raceId) external view returns (uint256[1] memory);
    function totalWagered(uint256 raceId) external view returns (uint256);
}
