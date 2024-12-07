// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20("MockToken", "MCK") {
    function mint(address recipient, uint256 amount) external returns (bool) {
        _mint(recipient, amount);
        return true;
    }
}
