// SPDX-License-Identifier: CC0-1.0
pragma solidity "0.8.28";

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IOracle} from "./IOracle.sol";
import {IShUSD} from "./IShUSD.sol";

interface IManager {
    function MIN_COLLAT_RATIO() external view returns (uint256);

    function weth() external view returns (IERC20);

    function shUSD() external view returns (IShUSD);

    function oracle() external view returns (IOracle);

    function address2deposit(address) external view returns (uint256);

    function address2minted(address) external view returns (uint256);

    function deposit(uint256) external;

    function burn(uint256) external;

    function mint(uint256) external;

    function withdraw(uint256) external;

    function liquidate(address) external;

    function collatRatio(address) external view returns (uint256);
}
