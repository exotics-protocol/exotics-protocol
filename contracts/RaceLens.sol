//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IExotic.sol";


/// @title Helper contract for fetching data from the race.
contract RaceLens is Ownable {

    struct FullRace {
        uint64 raceId;
        uint256 totalWagered;
        uint256 result;
        uint256[1] raceResult;
        uint256 requestId;
    }

    struct FullBet {
        uint64 raceId;
        uint256 amount;
        address account;
        uint8[1] place;
        uint256 payout;
        bool paid;
        uint256 betId;
        uint256[1] raceResult;
        bool raceFinished;
    }

    IExotic public exotic;

    constructor(IExotic _exotic) {
        exotic = _exotic;
    }

    function setExotic(IExotic _exotic) external onlyOwner {
        exotic = _exotic;
    }

    function race(uint64 raceId) public view returns (FullRace memory) {
        require(raceId % exotic.frequency() == 0, "Invalid race ID");
        IExotic.Race memory _race = exotic.race(raceId);
        FullRace memory _returnRace;
        _returnRace.raceId = raceId;
        _returnRace.totalWagered = exotic.totalWagered(raceId);
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

        // requesting past what we have.
        if ((resultsPerPage * page) > betCount) {
            start = 0;
            end = 0;
        } else {
            start = betCount - (resultsPerPage * page);
            if (start > resultsPerPage) {
                end = start - resultsPerPage;
            } else {
                end = 0;
            }
            if (start > betCount) {
                end = betCount < resultsPerPage ? 0 : betCount - resultsPerPage;
                start = betCount;
            }
        }
        FullBet[] memory result = new FullBet[](start - end);
        uint256 i;
        uint256 counter;
        for(i = start; i > end ; i--) {
            IExotic.Bet memory _bet = exotic.userBet(user, i - 1);
            FullBet memory _returnBet;
            _returnBet.raceId = _bet.raceId;
            _returnBet.amount = _bet.amount;
            _returnBet.account = _bet.account;
            _returnBet.place = [_bet.prediction];
            _returnBet.paid = _bet.paid;

            uint256 _odds = exotic.odds(_bet.raceId, _bet.prediction);
            if (_odds != 0) {
                _returnBet.payout = (_bet.amount * 1e10) / _odds;
            }
            _returnBet.betId = i - 1;
            FullRace memory _race = race(_bet.raceId);
            _returnBet.raceResult = _race.raceResult;
            _returnBet.raceFinished = _race.result == 0 ? false : true;
            result[counter] = _returnBet;
            counter += 1;
        }
        return result;
    }

}
