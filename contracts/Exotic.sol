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
        uint256 raceId;
        uint256 amount;
        address account;
        uint256[] place;
        bool paid;
    }

    struct Race {
        uint256 fee;  // House take in bps
        uint256 totalWagered;
        uint256 paid;
        uint256 result;
        uint256[6][3] weights;
    }

    /// @notice The state for each race.
    mapping(uint256 => Race) public race;
    /// @notice mapping of address to list of bets.
    mapping(address => Bet[]) public bet;
    /// @notice used internally to map races to VRF requests.
    mapping(uint256 => uint256) private requestIdRace;

    constructor(uint64 subscriptionId, address _vrfCoordinator) VRFConsumerBaseV2(_vrfCoordinator) {
		COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        start = block.timestamp;
		s_subscriptionId = subscriptionId;
    }

	/// @notice The time of the next race to take place.
	function nextRaceId() external view returns (uint256) {
		return block.timestamp + (frequency - (block.timestamp % frequency));
	}

    /// @notice Get the current odds for a prediction.
    function odds(uint256 raceId, uint256[] memory result) public view returns (uint256) {
        Race memory _race = race[raceId];
        require(result.length == 1, "Only win bet currently supported");
        uint256 total;
        uint256 i;
        for (i = 0; i < 6; i++) {
            total += _race.weights[0][i];
        }
        if (total == 0) return total;
        return (_race.weights[0][result[0]] * 1e10) / total;
    }

    /// @notice Place a bet.
    function placeBet(
        uint256 raceId,
        uint256[] calldata prediction
    ) external payable returns (uint256 betId) {
        validateRaceID(raceId);
        require(prediction.length == 1, "Only win bet currently supported");

        // Create the bet.
        Bet memory _bet;
        _bet.raceId = raceId;
        _bet.amount = msg.value;
        _bet.account = msg.sender;
        bet[msg.sender].push(_bet);
        bet[msg.sender][bet[msg.sender].length - 1].place.push(prediction[0]);

        // Update the race.
        Race storage _race = race[raceId];
        _race.weights[0][prediction[0]] += msg.value;
        _race.totalWagered += msg.value;

        // Internal accounting.
        balance += msg.value;
        return bet[msg.sender].length - 1;
    }

    /// @notice Cash out a winning bet.
    function payout(uint256 betId) external {
        Bet storage _bet = bet[msg.sender][betId];
        Race storage _race = race[_bet.raceId];
        require(_race.result != 0, "Race not finished");
        require(!_bet.paid, "Bet already paid");

        uint256[6] memory result = raceResult(_bet.raceId);
        uint256 i;
        for (i = 0; i < _bet.place.length; i++) {
            if (_bet.place[i] != result[i]) {
                return;
            }
        }
        uint256 _odds = odds(_bet.raceId, _bet.place);
        uint256 _payout = (_bet.amount * 1e10) / _odds;
        _bet.paid = true;
        _race.paid += _payout;
        balance -= _payout;
        payable(msg.sender).transfer(_payout);
    }

    /// @notice End the race and request result from VRF.
    function endRace(uint256 raceId) external {
        validateRaceID(raceId);
        require(block.timestamp > raceId + frequency, "Race not finished");
        require(requestIdRace[raceId] == 0, "Result already requested");
        Race storage _race = race[raceId];
        require(_race.result == 0, "Race result already fulfilled");
	 	uint256 s_requestId = COORDINATOR.requestRandomWords(
		  keyHash,
		  s_subscriptionId,
		  requestConfirmations,
		  callbackGasLimit,
		  numWords
		);
        requestIdRace[s_requestId] = raceId;
    }

    /// @notice VRF callback function.
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 raceId = requestIdRace[requestId];
        Race storage _race = race[raceId];
        require(_race.result == 0, "Randomness already fulfilled");
        _race.result = randomWords[0];
    }

    /// @notice Validate a `raceId` is valid to make a bet on.
    function validateRaceID(uint256 raceId) internal view {
        // Need to validate race length isn't finished
        require(raceId % frequency == 0, "Invalid race ID");
        require(raceId >= start, "Living in the past bro");
        require(race[raceId].result == 0, "Race finished");
        require(requestIdRace[raceId] == 0, "Race finising");
    }

    /// @notice Return the results for a race.
    function raceResult(uint256 raceId) public view returns (uint256[6] memory) {
        Race memory _race = race[raceId];
        require(_race.result != 0, "Race is not finished");
        uint256[6] memory result;

        uint256 total;
        uint256 i;
        for (i = 0; i < 6; i++) {
            total += _race.weights[0][i];
        }
        uint256 number = _race.result % total;

        uint256 j;
        for (j = 0; j < 6; j++) {
            if (_race.weights[0][j] > number) {
                result[0] = j;
            } else {
                number -= _race.weights[0][j];
            }
        }
        return result;
    }

}
