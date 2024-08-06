//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/*
* @title Oraclelib
* @author atrick collins
* @notice This library is used to check the chainlink oracle for the stale data
* If a price is stale, the function will revert and render the DscEngine unusable
* We want the DscEngine to freeze if price becomes stale.
*
* So if your chainlink network explodes and you have a lot of money locked in the protocol... too ...Bad.
*
*/

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib_StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib_StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
