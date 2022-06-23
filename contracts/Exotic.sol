//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/// @title An betting game with exotic bet types
contract Exotic is VRFConsumerBaseV2 {

	// Chainlink VRF required variables.
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;
    address vrfCoordinator;
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords =  1;

    uint256 private balance;

    /// @notice How often races take place.
    uint256 public constant frequency = 10 minutes;

    /// @notice The datetime of the first race.
    uint256 public immutable start;

    struct Bet {
        uint256 amount;
        address account;
        uint256[] place;
        bool paid;
    }

    struct Race {
        uint256 fee;  // House take in bps
        uint256 totalWagered;
        uint256 paid;
        uint256[] result;
        Bet[] bets;
        uint256[6][6] weights;
    }

    /// @notice The state for each race.
    mapping(uint256 => Race) public race;
    mapping(uint256 => uint256) private requestIdRace;

    constructor(uint64 subscriptionId, address _vrfCoordinator) VRFConsumerBaseV2(_vrfCoordinator) {
		COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        start = block.timestamp;
		s_subscriptionId = subscriptionId;
    }

    /// @notice Place a win bet.
    function win(
        uint256 raceId,
        uint256 first
    ) external payable returns (uint256 betId) {
        validateRaceID(raceId);

		console.log('raceId', raceId);

        uint256[] memory place;
        // Create the bet.
        Bet memory bet = Bet(msg.value, msg.sender, place, false);
        // Get a race and push the new bet to it.
        Race storage _race = race[raceId];
        _race.bets.push(bet);
        // Add the bet.
		console.log('bets len', _race.bets.length);
        _race.bets[_race.bets.length-1].place.push(first);

        // Update the weight table.
        _race.weights[0][first] += msg.value;
		console.log('updated race weights [0][first]', _race.weights[0][first]);
        _race.totalWagered += msg.value;
        balance += msg.value;
        betId = _race.bets.length;
    }

    /// @notice Place a forecast bet.
    function forecast(
        uint256 raceId,
        uint256 amount,
        uint256 first,
        uint256 second
    ) external payable {
        validateRaceID(raceId);
        raceId; amount; first; second;
    }

    /// @notice place a tricast bet.
    function tricast(
        uint256 raceId,
        uint256 amount,
        uint256 first,
        uint256 second,
        uint256 third
    ) external payable {
        validateRaceID(raceId);
        raceId; amount; first; second; third;
    }

    function payout(
        uint256 raceId,
        uint256 betId
    ) external {
        Race storage _race = race[raceId];
        require(_race.result.length != 0, "Race not finished");
        require(_race.bets[betId].account == msg.sender, "Not bet owner");
        Bet storage _bet = _race.bets[betId];
        require(!_bet.paid, "Bet already paid");
        // We need the result.
        uint256[] memory result = raceResult(raceId);
        // Need to check if bet was a winning bet.
        uint256 i;
        bool winner = true;
        for (i = 0; i < _bet.place.length; i++) {
            if (_bet.place[i] != result[i]) {
                winner = false;
            }
        }
        if (!winner) {
            return;
        }
        // We need to calculate the winnings.
        uint256 _odds = odds(raceId, _bet.place);
        uint256 _payout = _odds * _bet.amount;
        _bet.paid = true;
        _race.paid += _payout;
        balance -= _payout;
        payable(msg.sender).transfer(_payout);
    }

	// The value of a bet.
	function betValue(uint256 raceId, uint256 betId) external view returns (uint256) {

	}

	// @title the time of the next race.
	function nextRaceId() external view returns (uint256) {
		return block.timestamp + (frequency - (block.timestamp % frequency));
	}

	function results(uint256 raceId) public view returns (uint256[] memory) {
        Race memory _race = race[raceId];
		console.log('race `results` set in memory', _race.result.length);
		return _race.result;
	}

    function endRace(uint256 raceId) external {
        validateRaceID(raceId);
		console.log('timestamp of block at endRace', block.timestamp);
		console.log('raceId at endRace', raceId);
        require(block.timestamp > raceId + frequency, "Race not finished");
        require(requestIdRace[raceId] == 0, "Result already requested");
        Race storage _race = race[raceId];
        require(_race.result.length == 0, "Race result already fulfilled");
	 	uint256 s_requestId = COORDINATOR.requestRandomWords(
		  keyHash,
		  s_subscriptionId,
		  requestConfirmations,
		  callbackGasLimit,
		  numWords
		);
		console.log('race ended', s_requestId, raceId);
        requestIdRace[s_requestId] = raceId;
		console.log('race id saved?', requestIdRace[s_requestId]);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
		console.log('fulfillRandomWords called', randomWords[0], requestId);
        uint256 raceId = requestIdRace[requestId];
		console.log('raceId ', raceId);
        Race storage _race = race[raceId];
        require(_race.result.length == 0, "Randomness already fulfilled");
        _race.result.push(randomWords[0]);
        require(_race.result.length != 0, "Randomness already fulfilled");
		console.log('is the result getting set?', _race.result[0]);
    }

    function validateRaceID(uint256 raceId) internal view {
        // Need to validate race length isn't finished
        require(raceId % frequency == 0, "Invalid race ID");
        require(raceId >= start, "Living in the past bro");
        require(race[raceId].result.length == 0, "Race finished");
        require(requestIdRace[raceId] == 0, "Race finising");
    }

    function odds(uint256 raceId, uint256[] memory result) public view returns (uint256) {
        Race memory _race = race[raceId];
        require(result.length <= 3, "Only tricast supported");
        uint256 notSelected = _race.weights.length - result.length;
		console.log('notSelected ', notSelected);
        uint256 placeMultiplier = factorial(notSelected);
		console.log('placeMultiplier', placeMultiplier);
		uint256 wildMultiplier = factorial(notSelected > 0 ? notSelected - 1 : 0);
		console.log('wildMultiplier', wildMultiplier);

		uint256 total;
        uint256 i; uint256 j;
		for (i = 0; i < _race.weights.length; i++) {
			//console.log('start of iter', total);
            if (i < result.length) {
                total += placeMultiplier * _race.weights[i][result[i]];
            } else if (i >= result.length) {
                for (j = 0; j < _race.weights[i].length; j++) {
                    if (!contains(result, j)) {
                        total += wildMultiplier * _race.weights[i][j];
                    }
                }
            }
		}

        uint256 all;
        uint256 allMultiplier = factorial(_race.weights.length - 1);
		for (i = 0; i < _race.weights.length; i++) {
			//console.log('start of iter in all', all);
            for (j = 0; j < _race.weights[i].length; j++) {
                all += allMultiplier * _race.weights[i][j];
            }
        }
		console.log('total * 1e10 / all', (total * 1e10) / all);
        return (total * 1e10) / all;
    }

    function raceResult(uint256 raceId) public view returns (uint256[] memory result) {
        Race memory _race = race[raceId];
        uint256 i;
        uint256 j;
        uint256[] memory placeOdds;
        uint256 sumPlaceOdds;
        uint256[] memory bet;
        for (i = 0; i < 3; i++) {
            delete placeOdds;
            sumPlaceOdds = 0;
            uint256[6] memory weights = _race.weights[i];
            for (j = 0; j <= weights.length; j++) {
                delete bet;
                bet[0] = j;
                if (!contains(result, j)) {
                    uint256 _odd = odds(raceId, bet);
                    placeOdds[i] = _odd;
                    sumPlaceOdds += _odd;
                } else {
                    placeOdds[i] = 0;
                }
            }

        }
    }

    function factorial(uint256 x) internal pure returns (uint256) {
        if (x == 0) {
		  return 1;
		}
		else {
		  return x*factorial(x-1);
		}
    }

    /// @dev this will only be used where `bet` contains at most 3 items
    /// so is probably optimal in that range. Don't use it for larger arrays.
    function contains(uint256[] memory bet, uint256 contestant) internal pure returns (bool) {
        uint i;
        for (i = 0; i < bet.length; i++) {
            if (bet[i] == contestant) {
                return true;
            }
        }
        return false;
    }
}
