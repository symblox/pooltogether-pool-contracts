pragma solidity >=0.6.0 <0.7.0;

import './SingleRandomWinnerCoinHarness.sol';
import '../external/openzeppelin/ProxyFactory.sol';

contract SingleRandomWinnerCoinHarnessProxyFactory is ProxyFactory {
  SingleRandomWinnerCoinHarness public instance;

  constructor() public {
    instance = new SingleRandomWinnerCoinHarness();
  }

  function create() external returns (SingleRandomWinnerCoinHarness) {
    return SingleRandomWinnerCoinHarness(deployMinimal(address(instance), ''));
  }
}
