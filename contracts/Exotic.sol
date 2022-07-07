//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IRandomProvider.sol";
import "./interfaces/IRewarder.sol";


/// @title An betting game with exotic bet types
contract Exotic is Initializable, OwnableUpgradeable {

    IRandomProvider public randomProvider;

    /// @notice How often races take place.
    uint64 public frequency;

    /// @notice The datetime of the first race.
    uint256 public start;

    /// @notice Fee paramaters.
    uint256 public revenueFee;  // House take in bps
    uint256 public polFee;  // pol contribution in bps
    address public revenueAddress;
    address public polAddress;
    uint256 public maxBet;

    IRewarder public rewarder;

    struct Bet {
        uint256 amount;
        address account;
        uint64 raceId;
        uint8 prediction;
        bool paid;
    }

    struct Race {
        uint256 result;
        uint256 requestId;
        uint256[6] winWeights;
    }

    /// @notice The state for each race.
    mapping(uint64 => Race) public race;
    /// @notice mapping of address to list of bets.
    mapping(address => Bet[]) public bet;
    /// @notice used internally to map races to VRF requests.
    mapping(uint256 => uint64) private requestIdRace;

    mapping(uint256 => mapping(address => uint256[])) public betsPerRace;

    /// @notice emitted when a new bet is placed on a race.
    event Wagered(
        uint64 indexed raceId,
        address indexed from,
        uint256 amount,
        uint8 prediction,
        uint256 poolTotal
    );

    /// @notice emitted when a bet is cashed out.
    event Payout(
        uint64 indexed raceId,
        address indexed to,
        uint256 amount,
        uint8 prediction,
        uint256 payout
    );

    /// @notice emitted when a race starts.
    event RaceStart(
        uint64 indexed raceId,
        uint256 totalValue
    );
    /// @notice emitted when a race ends.
    event RaceEnd(
        uint64 indexed raceId,
        uint256 totalValue,
        uint256 result
    );

    event MaxBetUpdated(uint256 maxBet);
    event RevenueAddressUpdated(address indexed revenueAddress);
    event RevenueFeeUpdated(uint256 revenueFee);
    event POLAddressUpdated(address indexed polAddress);
    event POLFeeUpdated(uint256 polFee);
    event RewarderUpdated(address indexed rewarder);

    function initialize(
        address _randomProviderAddress,
        uint256 _revenueFee,
        uint256 _polFee,
        address _revenueAddress,
        address _polAddress,
        uint256 _maxBet,
        uint64 _frequency
    ) public initializer {
        start = block.timestamp;
        randomProvider = IRandomProvider(_randomProviderAddress);
        revenueFee = _revenueFee;
        polFee = _polFee;
        revenueAddress = _revenueAddress;
        polAddress = _polAddress;
        maxBet = _maxBet;
        frequency = _frequency;
        __Ownable_init();
    }

    function updateRewarder(IRewarder _rewarder) external onlyOwner {
        rewarder = _rewarder;
        emit RewarderUpdated(address(_rewarder));
    }

    function updateMaxBet(uint256 _maxBet) external onlyOwner {
        maxBet = _maxBet;
        emit MaxBetUpdated(maxBet);
    }

    function updateRevenueFee(uint256 _revenueFee) external onlyOwner {
        revenueFee = _revenueFee;
        emit RevenueFeeUpdated(_revenueFee);
    }

    function updateRevenueAddress(address _revenueAddress) external onlyOwner {
        require(_revenueAddress != address(0), "Fee address can't be 0");
        revenueAddress = _revenueAddress;
        emit RevenueAddressUpdated(_revenueAddress);
    }

    function updatePOLFee(uint256 _polFee) external onlyOwner {
        polFee = _polFee;
        emit POLFeeUpdated(_polFee);
    }

    function updatePOLAddress(address _polAddress) external onlyOwner {
        require(_polAddress != address(0), "Fee address can't be 0");
        polAddress = _polAddress;
        emit POLAddressUpdated(_polAddress);
    }

    /// @notice Return the amount of bets a user has made.
    function userBetCount(address user) public view returns (uint256) {
        return bet[user].length;
    }

    /// @notice Returns a users bet with given id.
    function userBet(
        address user, uint256 betId
    ) external view returns (
        Bet memory
    ) {
        return bet[user][betId];
    }

	/// @notice The time of the next race to take place.
	function nextRaceId() external view returns (uint256) {
		return block.timestamp + (frequency - (block.timestamp % frequency));
	}

    function currentRaceId() external view returns (uint256) {
        return block.timestamp - (block.timestamp % frequency);
    }

    function totalWagered(uint64 raceId) public view returns (uint256)  {
        Race memory _race = race[raceId];
        return _race.winWeights[0] +
            _race.winWeights[1] +
            _race.winWeights[2] +
            _race.winWeights[3] +
            _race.winWeights[4] +
            _race.winWeights[5];
    }

    /// @notice Get the current odds for a prediction.
    function odds(uint64 raceId, uint8 result) public view returns (uint256) {
        Race memory _race = race[raceId];
        require(result < 6, "Only win bet currently supported");
        uint256 total = totalWagered(raceId);
        if (total == 0) return 0;
        return (_race.winWeights[result] * 1e10) / total;
    }

    /// @notice Start the race and request result from VRF.
    function startRace(uint64 raceId) public {
        validateRaceID(raceId);
        require(block.timestamp > raceId, "Race not finished");
        Race storage _race = race[raceId];
        require(_race.requestId == 0, "Result already requested");
        require(_race.result == 0, "Race result already fulfilled");
	 	uint256 s_requestId = randomProvider.requestRandomWords();
        _race.requestId = s_requestId;
        requestIdRace[s_requestId] = raceId;
        emit RaceStart(
            raceId,
            totalWagered(raceId)
        );
    }

    /// @notice Place a bet.
    function placeBet(
        uint64 raceId,
        uint8 prediction
    ) external payable returns (uint256 betId) {

        require(raceId % frequency == 0, "Invalid race ID");

        Race storage _race = race[raceId];
        require(_race.requestId == 0, "Race finising");
        require(prediction < 6, "Only 6 faces of dice");

        uint256 _revenueFee = msg.value * revenueFee / 10000;
        uint256 _polFee = msg.value * polFee / 10000;
        uint256 betValue = msg.value - (_revenueFee + _polFee);

        require(betValue <= maxBet, "Bet above maxBet limit");

        // Create the bet.
        Bet memory _bet = Bet(betValue, msg.sender, raceId, prediction, false);
        bet[msg.sender].push(_bet);
        betId = bet[msg.sender].length - 1;

        // Update the race.
        _race.winWeights[prediction] += betValue;
        betsPerRace[raceId][msg.sender].push(betId);

        emit Wagered(
            raceId,
            msg.sender,
            betValue,
            prediction,
            totalWagered(raceId)
        );

        if (raceId < block.timestamp) {
            startRace(raceId);
        }
        if (address(rewarder) != address(0)) {
            rewarder.addReward(msg.sender, msg.value);
        }
        (bool sent, ) = payable(polAddress).call{value: _polFee}("");
        require(sent, "POL Fee not sent");
        (sent, ) = payable(revenueAddress).call{value: _revenueFee}("");
        require(sent, "Revenue Fee not sent");
        return betId;
    }

    function betsOnRace(address user, uint64 raceId) external view returns (Bet[] memory) {
        uint256[] memory betIds = betsPerRace[raceId][user];
        uint256 i;
        Bet[] memory result = new Bet[](betIds.length);
        for (i = 0; i < betIds.length; i++){
            result[i] = bet[user][betIds[i]];
        }
        return result;
    }

    /// @notice Cash out a winning bet.
    function payout(uint256 betId) external {
        Bet storage _bet = bet[msg.sender][betId];
        Race storage _race = race[_bet.raceId];
        require(_race.result != 0, "Race not finished");
        require(!_bet.paid, "Bet already paid");

        uint256[1] memory result = raceResult(_bet.raceId);
        if (_bet.prediction != result[0]) {
            return;
        }
        uint256 _odds = odds(_bet.raceId, _bet.prediction);
        uint256 _payout = (_bet.amount * 1e10) / _odds;
        _bet.paid = true;
        emit Payout(
            _bet.raceId,
            msg.sender,
            _bet.amount,
            _bet.prediction,
            _payout
        );
        payable(msg.sender).transfer(_payout);
    }

    /// @notice End the race and set the result.
    function endRace(
        uint256 requestId,
        uint256[] memory randomWords
    ) external {
        require(msg.sender == address(randomProvider), "Not Allowed randomProvider");
        uint64 raceId = requestIdRace[requestId];
        Race storage _race = race[raceId];
        require(_race.result == 0, "Randomness already fulfilled");
        _race.result = randomWords[0];
        emit RaceEnd(
            raceId,
            totalWagered(raceId),
            randomWords[0]
        );
    }

    /// @notice Validate a `raceId` is valid to make a bet on.
    function validateRaceID(uint64 raceId) internal view {
        // Need to validate race length isn't finished
        require(raceId % frequency == 0, "Invalid race ID");
        require(raceId >= start, "Living in the past bro");
        require(race[raceId].result == 0, "Race finished");
        require(requestIdRace[raceId] == 0, "Race finising");
    }

    /// @notice Return the results for a race.
    function raceResult(uint64 raceId) public view returns (uint256[1] memory) {
        Race memory _race = race[raceId];
        require(_race.result != 0, "Race is not finished");

        uint256 i;

        uint256 total;
        for (i = 0; i < 6; i++) {
            total += _race.winWeights[i];
        }

        uint256[1] memory result;
        uint256 number = _race.result % total;
        for (i = 0; i < 6; i++) {
            if (_race.winWeights[i] > number) {
                result[0] = i;
                break;
            } else {
                number -= _race.winWeights[i];
            }
        }
        return result;
    }

}
