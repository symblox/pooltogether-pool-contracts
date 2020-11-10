// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import './SyxPrizePool.sol';
import '../../external/openzeppelin/ProxyFactory.sol';

/// @title syx Prize Pool Proxy Factory
/// @notice Minimal proxy pattern for creating new syx Prize Pools
contract SyxPrizePoolProxyFactory is ProxyFactory {
  /// @notice Contract template for deploying proxied Prize Pools
  SyxPrizePool public instance;

  /// @notice Initializes the Factory with an instance of the syx Prize Pool
  constructor() public {
    instance = new SyxPrizePool();
  }

  /// @notice Creates a new Stake Prize Pool as a proxy of the template instance
  /// @return A reference to the new proxied Stake Prize Pool
  function create() external returns (SyxPrizePool) {
    return SyxPrizePool(uint160(deployMinimal(address(instance), '')));
  }
}
