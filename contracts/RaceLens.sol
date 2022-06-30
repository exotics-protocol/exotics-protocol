//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IExotic.sol";


/// @title Helper contract for fetching data from the race.
contract RaceLens is Ownable {

    struct FullRace {
        uint256 raceId;
        uint256 totalWagered;
        uint256 paid;
        uint256 result;
        uint256[6] raceResult;
        uint256 requestId;
    }

    struct FullBet {
        uint256 raceId;
        uint256 amount;
        address account;
        uint256[] place;
        bool paid;
        uint256 betId;
        uint256[6] raceResult;
        bool raceFinished;
    }

    IExotic public exotic;

    constructor(IExotic _exotic) {
        exotic = _exotic;
    }

    function setExotic(IExotic _exotic) external onlyOwner {
        exotic = _exotic;
    }

    function race(uint256 raceId) public view returns (FullRace memory) {
        require(raceId % exotic.frequency() == 0, "Invalid race ID");
        IExotic.Race memory _race = exotic.race(raceId);
        FullRace memory _returnRace;
        _returnRace.raceId = raceId;
        _returnRace.totalWagered = _race.totalWagered;
        _returnRace.paid = _race.paid;
        _returnRace.result = _race.result;
        _returnRace.requestId = _race.requestId;
        if (_race.result != 0) {
            _returnRace.raceResult = exotic.raceResult(raceId);
        }

        return _returnRace;
    }

    function userBets(
        address user, uint256 resultsPerPage, uint256 page
    ) public view returns (
        FullBet[] memory
    ) {
        uint256 betCount = exotic.userBetCount(user);
        uint256 start;
        uint256 end;

        if (betCount < (resultsPerPage * page) - resultsPerPage) {
            start = 0;
            end = 0;
        } else if (betCount < resultsPerPage * page) {
            start = resultsPerPage * page - resultsPerPage;
            end = betCount;
        } else {
            start = resultsPerPage * page - resultsPerPage;
            end = resultsPerPage * page;
        }
        FullBet[] memory result = new FullBet[](end - start);
        uint256 i;
        uint256 counter;
        for(i = start; i < end; i++) {
            IExotic.Bet memory _bet = exotic.userBet(user, i);
            FullBet memory _returnBet;
            _returnBet.raceId = _bet.raceId;
            _returnBet.amount = _bet.amount;
            _returnBet.account = _bet.account;
            _returnBet.place = _bet.place;
            _returnBet.paid = _bet.paid;
            _returnBet.betId = i;

            FullRace memory _race = race(_bet.raceId);
            _returnBet.raceResult = _race.raceResult;
            _returnBet.raceFinished = _race.result == 0 ? false : true;
            result[counter] = _returnBet;
            counter += 1;
        }
        return result;
    }

}



