pragma solidity >=0.6.0 <0.7.0;

import './SyxSingleWinnerHarness.sol';
import '../external/openzeppelin/ProxyFactory.sol';

contract SyxSingleWinnerHarnessProxyFactory is ProxyFactory {
  SyxSingleWinnerHarness public instance;

  constructor() public {
    instance = new SyxSingleWinnerHarness();
  }

  function create() external returns (SyxSingleWinnerHarness) {
    return SyxSingleWinnerHarness(deployMinimal(address(instance), ''));
  }
}
