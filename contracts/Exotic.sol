//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "./interfaces/IRandomProvider.sol";


/// @title An betting game with exotic bet types
contract Exotic {

    IRandomProvider public randomProvider;

    uint256 private balance;

    /// @notice How often races take place.
    uint256 public constant frequency = 3 minutes;

    /// @notice The datetime of the first race.
    uint256 public immutable start;

    /// @notice Fee paramaters.
    uint256 public fee;  // House take in bps
    uint256 public jackpotContribution;  // Jackpot contribution in bps
    address public feeAddress;
    address public jackpotAddress;

    struct Bet {
        uint256 raceId;
        uint256 amount;
        address account;
        uint256[] place;
        bool paid;
    }

    struct Race {
        uint256 totalWagered;
        uint256 paid;
        uint256 result;
        uint256 requestId;
        uint256[6][3] weights;
    }

    /// @notice The state for each race.
    mapping(uint256 => Race) public race;
    /// @notice mapping of address to list of bets.
    mapping(address => Bet[]) public bet;
    /// @notice used internally to map races to VRF requests.
    mapping(uint256 => uint256) private requestIdRace;

    /// @notice emitted when a new bet is placed on a race.
    event Wagered(
        uint256 indexed raceId,
        address indexed from,
        uint256 amount,
        uint256[] prediction,
        uint256 poolTotal
    );

    /// @notice emitted when a bet is cashed out.
    event Payout(
        uint256 indexed raceId,
        address indexed to,
        uint256 amount,
        uint256[] prediction,
        uint256 payout
    );

    /// @notice emitted when a race starts.
    event RaceStart(
        uint256 indexed raceId,
        uint256 totalValue
    );
    /// @notice emitted when a race ends.
    event RaceEnd(
        uint256 indexed raceId,
        uint256 totalValue,
        uint256 result
    );

    constructor(
        address _randomProviderAddress,
        uint256 _fee,
        uint256 _jackpotContribution,
        address _feeAddress,
        address _jackpotAddress
    ) {
        start = block.timestamp;
        randomProvider = IRandomProvider(_randomProviderAddress);
        fee = _fee;
        jackpotContribution = _jackpotContribution;
        feeAddress = _feeAddress;
        jackpotAddress = _jackpotAddress;
    }

    /// @notice Return the amount of bets a user has made.
    function userBetCount(address user) external view returns (uint256) {
        return bet[user].length;
    }

    /// @notice Returns a users bet with given id.
    function userBet(
        address user, uint256 betId
    ) external view returns (
        uint256, uint256, uint256[] memory, bool
    ) {
        Bet memory _bet = bet[user][betId];
        return (_bet.raceId, _bet.amount, _bet.place, _bet.paid);
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

        uint256 betFee = msg.value * fee / 10000;
        uint256 jackpotFee = msg.value * jackpotContribution / 10000;
        uint256 betValue = msg.value - (betFee + jackpotFee);

        // Create the bet.
        Bet memory _bet;
        _bet.raceId = raceId;
        _bet.amount = betValue;
        _bet.account = msg.sender;
        bet[msg.sender].push(_bet);
        bet[msg.sender][bet[msg.sender].length - 1].place.push(prediction[0]);

        // Update the race.
        Race storage _race = race[raceId];
        _race.weights[0][prediction[0]] += betValue;
        _race.totalWagered += betValue;

        // Internal accounting.
        balance += betValue;
        emit Wagered(
            raceId,
            msg.sender,
            betValue,
            prediction,
            balance
        );
        payable(feeAddress).transfer(betFee);
        payable(jackpotAddress).transfer(jackpotFee);
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
        emit Payout(
            _bet.raceId,
            msg.sender,
            _bet.amount,
            _bet.place,
            _payout
        );
        payable(msg.sender).transfer(_payout);
    }

    /// @notice Start the race and request result from VRF.
    function startRace(uint256 raceId) external {
        validateRaceID(raceId);
        require(block.timestamp > raceId + frequency, "Race not finished");
        Race storage _race = race[raceId];
        require(_race.requestId == 0, "Result already requested");
        require(_race.result == 0, "Race result already fulfilled");
	 	uint256 s_requestId = randomProvider.requestRandomWords();
        _race.requestId = s_requestId;
        requestIdRace[s_requestId] = raceId;
        emit RaceStart(
            raceId,
            balance
        );
    }

    /// @notice End the race and set the result.
    function endRace(
        uint256 requestId,
        uint256[] memory randomWords
    ) external {
        require(msg.sender == address(randomProvider), "Not Allowed randomProvider");
        uint256 raceId = requestIdRace[requestId];
        Race storage _race = race[raceId];
        require(_race.result == 0, "Randomness already fulfilled");
        _race.result = randomWords[0];
        emit RaceEnd(
            raceId,
            balance,
            randomWords[0]
        );
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
