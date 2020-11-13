// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import '../PeriodicPrizeStrategy.sol';
import '../../interface/ISponsor.sol';

/* solium-disable security/no-block-members */
/* only award external tokens*/
contract SingleRandomWinnerCoin is PeriodicPrizeStrategy {
  ISponsor public sponsor;

  function initialize(
    address _trustedForwarder,
    uint256 _prizePeriodStart,
    uint256 _prizePeriodSeconds,
    PrizePool _prizePool,
    address _ticket,
    address _sponsorship,
    RNGInterface _rng,
    address[] memory _externalErc20s,
    address _sponsor
  ) public initializer {
    super.initialize(
      _trustedForwarder,
      _prizePeriodStart,
      _prizePeriodSeconds,
      _prizePool,
      _ticket,
      _sponsorship,
      _rng,
      _externalErc20s
    );
    sponsor = ISponsor(_sponsor);
  }

  function startAward() public override requireCanStartAward {
    sponsor.getReward();
    super.startAward();
  }

  function _distribute(uint256 randomNumber) internal override {
    uint256 prize = prizePool.captureAwardBalance();
    address winner = ticket.draw(randomNumber);
    if (winner != address(0) && winner != sponsor.ticketHolder()) {
      _awardTickets(winner, prize);
      _awardAllExternalTokens(winner);
    }
  }
}
