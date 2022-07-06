//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


/// @title the brain and POL of exotics
contract House is Initializable, OwnableUpgradeable {

    struct Game {
        address gameAddress;
        bool enabled;
    }
    mapping(address => Game) public game;

    function initialize() public initializer{
        __Ownable_init();
    }

    function addGame(
        address gameAddress,
        bool enabled
    ) external onlyOwner {
        require(game[gameAddress].gameAddress == address(0), "Game already added");
        require(gameAddress != address(0), "Game 0 address");
        game[gameAddress].gameAddress = gameAddress;
        game[gameAddress].enabled = enabled;
    }

    function updateGame(
        address gameAddress,
        bool enabled
    ) external onlyOwner {
        game[gameAddress].enabled = enabled;
    }

    fallback() external payable {}
    receive() external payable {}

}
