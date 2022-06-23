# Dog racing simulator

This documents provides an indepth look at the dog racing smart contract application. The application betting mechanic is a modified version of a [tote betting](https://en.wikipedia.org/wiki/Parimutuel_betting#Parimutuel_bet_types) system and a related set of smart contracts that allow the system to be ran in a distributed manner where no central party has custody of the funds or the possibility to "rig" a result.

## Game introduction

The game is analagous to a greyhound race. There are six dogs that compete and in this game users may place multiple bet types on the result of the race. A new race starts every 10 minutes with betting available 100 minutes before it starts, once a race starts no additional bets may be placed. A winning bet can be "cashed out" at anytime but must be claimed and is not paid automatically.

### Bet types

#### Win

Pick the dog that wins the race

#### Forecast

Pick two dogs to finish first and second in exact order

#### Tricast

Pick three dogs to finish first, second and third in exact order

## Parimutuel betting

As described above this games betting system is adapted from the tote betting system. In the classic tote system each bet type maintains its own pool of liquidity and on which its odds are determined. Our system uses a subset of bets available at the track but combines all wagers into a single liquidity pool. The advantages this achieves are:

* less slippage on bets
* more accurate odds

The downside to using a tote system (that our system unfortunatly requires) is that odds are not "fixed" at the time of the bet and only fix once the race has been started.

## Placing a bet

To place a bet a transaction must be sent to the deployed smart contract to one of the functions detailed here, these functions return a `betId` variable that is needed to claim a payout.

### Win bet

```
function win(uint256 raceId, uint256 first) external payable returns (uint256 betId)
```

This function is called with an argument `raceId` which is the timestamp the race starts at. The `first` argument is the index (0 based) of the dog the win bet is being placed on. The value sent with the transaction is the amount of currency being placed on the wager.

Example: place 1 ether bet on dog 0 to come first
> await Exotic.win(12431244, 0, {value: 1*10**18})

### Forecast bet

TODO

### Tricast bet

TODO

## Claiming a payout

To claim a payout the function `payout` is called.
```
function payout(uint256 raceId, uint256 betId) external
```
For the function to execute without reverting the caller of the function must be the same address as originally placed the bet and the race must be finished with the result provided..

## Selecting a winner

The game uses [chainlink vrf](https://docs.chain.link/docs/chainlink-vrf/) to fairly choose a winner for each race. VRF provides a random number that we use to select a winner. The algorithm used for selection is simplified but shown here
```
random_number = vrf()
for position in [1, 2, 3]
    weights = weights_for_position(position)
    combined_weight = sum(weights)
    winner = random_number * combined_weight
    for index, contestant_weight in weights:
        if contestant_weight > winner:
            set_position(position, index)
        else:
            winner -= contestant_weight
```

## Getting odds

Odds can be retrieved from a view function on the contract.

```
function odds(uint256 raceId, uint256[] memory result) public view returns (uint256)
```
Where `raceId` is as explained above and `result` is an array containing at minimum 1 (win bet) and at maximum 3 (tricast bet) arguments. This function returns the odds as a value between 0 and 10000000000 (this scaling is due to EVM limitations with decimal aritmethic but corresponds to a probability between 0 and 1). The UI of the application can translate this to classic odds given by sports betting eg. 10/1

## Getting race information

TODO Description

* weights
* total bets
* count bets
* start time
* paid out
* fee
* result
* bets

## Getting race result

```
function raceResult(uint256 raceId) public view returns (uint256[] memory result)
```
Returns a list of length 3 containing the first, second and third place of the race.
