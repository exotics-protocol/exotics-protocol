//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


import "./interfaces/IExotic.sol";


/// @title Helper contract for fetching data from the roll.
contract RollLens is Initializable, OwnableUpgradeable {

    struct FullRoll {
        uint64 rollId;
        uint256 totalWagered;
        uint256 result;
        uint256 rollResult;
        uint256 requestId;
    }

    struct FullBet {
        uint64 rollId;
        uint256 amount;
        address account;
        uint8 prediction;
        uint256 payout;
        bool paid;
        uint256 betId;
        uint256 rollResult;
        bool rollFinished;
    }

    IExotic public exotic;

    function initialize(IExotic _exotic) public initializer {
        exotic = _exotic;
        __Ownable_init();
    }

    function setExotic(IExotic _exotic) external onlyOwner {
        exotic = _exotic;
    }

    function roll(uint64 rollId) public view returns (FullRoll memory) {
        IExotic.Roll memory _roll = exotic.roll(rollId);
        FullRoll memory _returnRoll;
        _returnRoll.rollId = rollId;
        _returnRoll.totalWagered = exotic.totalWagered(rollId);
        _returnRoll.result = _roll.result;
        _returnRoll.requestId = _roll.requestId;
        if (_roll.result != 0) {
            _returnRoll.rollResult = exotic.rollResult(rollId);
        }

        return _returnRoll;
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
            _returnBet.rollId = _bet.rollId;
            _returnBet.amount = _bet.amount;
            _returnBet.account = _bet.account;
            _returnBet.prediction = _bet.prediction;
            _returnBet.paid = _bet.paid;

            uint256 _odds = exotic.odds(_bet.rollId, _bet.prediction);
            if (_odds != 0) {
                _returnBet.payout = (_bet.amount * 1e10) / _odds;
            }
            _returnBet.betId = i - 1;
            FullRoll memory _roll = roll(_bet.rollId);
            _returnBet.rollResult = _roll.rollResult;
            _returnBet.rollFinished = _roll.result == 0 ? false : true;
            result[counter] = _returnBet;
            counter += 1;
        }
        return result;
    }

    function probabilitySummary(uint64 rollId) public view returns (uint256[6] memory) {
        uint256[6] memory probabilities;
        uint8 i;
        for (i = 0; i < 6; i++) {
            probabilities[i] = exotic.odds(rollId, i);
        }
        return probabilities;
    }

    function decimalOdds(uint64 rollId) public view returns (uint256[6] memory) {
        uint256[6] memory dOdds;
        uint8 i;
        for (i = 0; i < 6; i++) {
            uint256 o = exotic.odds(rollId, i);
            if (o == 0) {
                dOdds[i] = 0;
            } else {
                dOdds[i] = 1e14 / o;
            }
        }
        return dOdds;
    }

    function estimateOdds(uint64 rollId, uint8 result, uint256 betAmount) public view returns (uint256) {
        uint256 currentTotal = exotic.totalWagered(rollId);
        uint256 currentWeight = exotic.currentWeight(rollId)[result];
        return 1e14 / (((currentWeight + betAmount) * 1e10) / (currentTotal + betAmount));
    }

    function userRollBets(
        uint64 rollId,
        address user,
        uint256 resultsPerPage,
        uint256 page
    ) public view returns (
        FullBet[] memory
    ) {
        uint256 betCount = exotic.userRollBetCount(rollId, user);
        uint256 start;
        uint256 end;
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
            IExotic.Bet memory _bet = exotic.userRollBet(rollId, user, i - 1);
            FullBet memory _returnBet;
            _returnBet.rollId = _bet.rollId;
            _returnBet.amount = _bet.amount;
            _returnBet.account = _bet.account;
            _returnBet.prediction = _bet.prediction;
            _returnBet.paid = _bet.paid;

            _returnBet.payout = exotic.odds(_bet.rollId, _bet.prediction) != 0 ?
                (_bet.amount * 1e10) /  exotic.odds(_bet.rollId, _bet.prediction) :
                0;

            _returnBet.betId = exotic.userRollBetId(user, rollId, i-1);

            FullRoll memory _roll = roll(_bet.rollId);
            _returnBet.rollResult = _roll.rollResult;
            _returnBet.rollFinished = _roll.result == 0 ? false : true;
            result[counter] = _returnBet;
            counter += 1;
        }
        return result;
    }


}
