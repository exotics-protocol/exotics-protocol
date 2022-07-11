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

    /// @notice How often rolls take place.
    uint64 public frequency;

    /// @notice The datetime of the first roll.
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
        uint64 rollId;
        uint8 prediction;
        bool paid;
    }

    struct Roll {
        uint256 result;
        uint256 requestId;
        uint256[6] winWeights;
    }

    /// @notice The state for each roll.
    mapping(uint64 => Roll) public roll;
    /// @notice mapping of address to list of bets.
    mapping(address => Bet[]) public bet;
    /// @notice used internally to map rolls to VRF requests.
    mapping(uint256 => uint64) private requestIdRoll;

    mapping(uint256 => mapping(address => uint256[])) public betsPerRoll;

    /// @notice emitted when a new bet is placed on a role.
    event Wagered(
        uint64 indexed rollId,
        address indexed from,
        uint256 amount,
        uint8 prediction,
        uint256 poolTotal
    );

    /// @notice emitted when a bet is cashed out.
    event Payout(
        uint64 indexed rollId,
        address indexed to,
        uint256 amount,
        uint8 prediction,
        uint256 payout
    );

    /// @notice emitted when a roll starts.
    event RollStart(
        uint64 indexed rollId,
        uint256 totalValue
    );
    /// @notice emitted when a roll ends.
    event RollEnd(
        uint64 indexed rollId,
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

    function userRollBetCount(uint256 rollId, address user) public view returns (uint256) {
        return betsPerRoll[rollId][user].length;
    }

    /// @notice returns a users bet with given id.
    function userBet(
        address user, uint256 betId
    ) external view returns (
        Bet memory
    ) {
        return bet[user][betId];
    }

    function userRollBet(
        uint64 rollId, address user, uint256 betId
    ) external view returns (
        Bet memory
    ) {
        return bet[user][betsPerRoll[rollId][user][betId]];
    }

	/// @notice The time of the next roll to take place.
	function nextRollId() external view returns (uint256) {
		return block.timestamp + (frequency - (block.timestamp % frequency));
	}

    function currentRollId() external view returns (uint256) {
        return block.timestamp - (block.timestamp % frequency);
    }

    function totalWagered(uint64 rollId) public view returns (uint256)  {
        Roll memory _roll = roll[rollId];
        return _roll.winWeights[0] +
            _roll.winWeights[1] +
            _roll.winWeights[2] +
            _roll.winWeights[3] +
            _roll.winWeights[4] +
            _roll.winWeights[5];
    }

    /// @notice Get the current odds for a prediction.
    function odds(uint64 rollId, uint8 result) public view returns (uint256) {
        Roll memory _roll = roll[rollId];
        require(result < 6, "Only win bet currently supported");
        uint256 total = totalWagered(rollId);
        if (total == 0) return 0;
        return (_roll.winWeights[result] * 1e10) / total;
    }

    function currentWeight(uint64 rollId) external view returns (uint256[6] memory) {
        return roll[rollId].winWeights;
    }

    /// @notice Start the roll and request result from VRF.
    function startRoll(uint64 rollId) public {
        validateRollId(rollId);
        require(block.timestamp > rollId, "Roll not finished");
        Roll storage _roll = roll[rollId];
        require(_roll.requestId == 0, "Result already requested");
        require(_roll.result == 0, "Roll result already fulfilled");
	 	uint256 s_requestId = randomProvider.requestRandomWords();
        _roll.requestId = s_requestId;
        requestIdRoll[s_requestId] = rollId;
        emit RollStart(
            rollId,
            totalWagered(rollId)
        );
    }

    /// @notice Place a bet.
    function placeBet(
        uint64 rollId,
        uint8 prediction
    ) external payable returns (uint256 betId) {

        require(rollId % frequency == 0, "Invalid roll ID");

        Roll storage _roll = roll[rollId];
        require(_roll.requestId == 0, "Roll finising");
        require(prediction < 6, "Only 6 faces of dice");

        uint256 _revenueFee = msg.value * revenueFee / 10000;
        uint256 _polFee = msg.value * polFee / 10000;
        uint256 betValue = msg.value - (_revenueFee + _polFee);

        require(betValue <= maxBet, "Bet above maxBet limit");

        // Create the bet.
        Bet memory _bet = Bet(betValue, msg.sender, rollId, prediction, false);
        bet[msg.sender].push(_bet);
        betId = bet[msg.sender].length - 1;

        // Update the roll.
        _roll.winWeights[prediction] += betValue;
        betsPerRoll[rollId][msg.sender].push(betId);

        emit Wagered(
            rollId,
            msg.sender,
            betValue,
            prediction,
            totalWagered(rollId)
        );

        if (rollId < block.timestamp) {
            startRoll(rollId);
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

    function betsOnRoll(address user, uint64 rollId) external view returns (Bet[] memory) {
        uint256[] memory betIds = betsPerRoll[rollId][user];
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
        Roll storage _roll = roll[_bet.rollId];
        require(_roll.result != 0, "Roll not finished");
        require(!_bet.paid, "Bet already paid");

        uint256 result = rollResult(_bet.rollId);
        if (_bet.prediction != result) {
            return;
        }
        uint256 _odds = odds(_bet.rollId, _bet.prediction);
        uint256 _payout = (_bet.amount * 1e10) / _odds;
        _bet.paid = true;
        emit Payout(
            _bet.rollId,
            msg.sender,
            _bet.amount,
            _bet.prediction,
            _payout
        );
        payable(msg.sender).transfer(_payout);
    }

    /// @notice End the roll and set the result.
    function endRoll(
        uint256 requestId,
        uint256[] memory randomWords
    ) external {
        require(msg.sender == address(randomProvider), "Not Allowed randomProvider");
        uint64 rollId = requestIdRoll[requestId];
        Roll storage _roll = roll[rollId];
        require(_roll.result == 0, "Randomness already fulfilled");
        _roll.result = randomWords[0];
        emit RollEnd(
            rollId,
            totalWagered(rollId),
            randomWords[0]
        );
    }

    /// @notice Validate a `rollId` is valid to make a bet on.
    function validateRollId(uint64 rollId) internal view {
        // Need to validate roll length isn't finished
        require(rollId % frequency == 0, "Invalid roll ID");
        require(rollId >= start, "Living in the past bro");
        require(roll[rollId].result == 0, "Roll finished");
        require(requestIdRoll[rollId] == 0, "Roll finising");
    }

    /// @notice Return the results for a roll.
    function rollResult(uint64 rollId) public view returns (uint256) {
        Roll memory _roll = roll[rollId];
        require(_roll.result != 0, "Roll is not finished");

        uint256 i;

        uint256 total;
        for (i = 0; i < 6; i++) {
            total += _roll.winWeights[i];
        }

        uint256 result;
        uint256 number = _roll.result % total;
        for (i = 0; i < 6; i++) {
            if (_roll.winWeights[i] > number) {
                result = i;
                break;
            } else {
                number -= _roll.winWeights[i];
            }
        }
        return result;
    }

}
