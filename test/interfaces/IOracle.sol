// SPDX-License-Identifier: CC0-1.0
pragma solidity "0.8.28";

interface IOracle {
    function latestAnswer() external view returns (uint256);
}
