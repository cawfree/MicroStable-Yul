// SPDX-License-Identifier: CC0-1.0oracle
pragma solidity 0.8.28;

import {IOracle} from "@test/interfaces/IOracle.sol";

contract MockOracle is IOracle {
    /// @inheritdoc IOracle
    uint256 public latestAnswer;

    function setLatestAnswer(uint256 latestAnswer_) external {
        latestAnswer = latestAnswer_;
    }
}
