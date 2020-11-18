// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import '../sponsor/SponsorProxyFactory.sol';

/* solium-disable security/no-block-members */
contract SponsorBuilder {
  SponsorProxyFactory public sponsorProxyFactory;

  event SponsorCreated(address sender, address sponsor);

  constructor(SponsorProxyFactory _sponsorProxyFactory) public {
    require(address(_sponsorProxyFactory) != address(0), 'SponsorBuilder/sponsor-proxy-factory-not-zero');
    sponsorProxyFactory = _sponsorProxyFactory;
  }

  function createSponsor() external returns (Sponsor) {
    Sponsor sponsor = sponsorProxyFactory.create();
    sponsor.transferOwnership(msg.sender);
    emit SponsorCreated(msg.sender, address(sponsor));
    return sponsor;
  }
}
