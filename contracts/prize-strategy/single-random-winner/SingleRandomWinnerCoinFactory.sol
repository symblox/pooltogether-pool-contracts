// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import './SingleRandomWinnerCoin.sol';
import '../../external/openzeppelin/ProxyFactory.sol';

contract SingleRandomWinnerCoinFactory is ProxyFactory {
  SingleRandomWinnerCoin public instance;

  constructor() public {
    instance = new SingleRandomWinnerCoin();
  }

  function create() external returns (SingleRandomWinnerCoin) {
    return SingleRandomWinnerCoin(deployMinimal(address(instance), ''));
  }
}
