// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import './Sponsor.sol';
import '../external/openzeppelin/ProxyFactory.sol';

contract SponsorProxyFactory is ProxyFactory {
  Sponsor public instance;

  /// @notice Initializes the Factory with an instance of the sponsor
  constructor() public {
    instance = new Sponsor();
  }

  /// @notice Creates a new sponsor as a proxy of the template instance
  /// @return A reference to the new proxied sponsor
  function create() external returns (Sponsor) {
    return Sponsor(uint160(deployMinimal(address(instance), '')));
  }
}
