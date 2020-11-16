// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import './Sponsor.sol';
import '../external/openzeppelin/ProxyFactory.sol';

contract SponsorProxyFactory is ProxyFactory {
  Sponsor public instance;

  event SponsorCreated(address sender, address sponsor);

  /// @notice Initializes the Factory with an instance of the sponsor
  constructor() public {
    instance = new Sponsor();
  }

  /// @notice Creates a new sponsor as a proxy of the template instance
  /// @return sponsor A reference to the new proxied sponsor
  function create() external returns (Sponsor) {
    Sponsor sponsor = Sponsor(uint160(deployMinimal(address(instance), '')));
    emit SponsorCreated(msg.sender, address(sponsor));
    return sponsor;
  }
}
