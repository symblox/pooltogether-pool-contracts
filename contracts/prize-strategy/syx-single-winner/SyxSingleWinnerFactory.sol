// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import "./SyxSingleWinner.sol";
import "../../external/openzeppelin/ProxyFactory.sol";

contract SyxSingleWinnerFactory is ProxyFactory {
  SyxSingleWinner public instance;

  constructor() public {
    instance = new SyxSingleWinner();
  }

  function create() external returns (SyxSingleWinner) {
    return SyxSingleWinner(deployMinimal(address(instance), ""));
  }
}
