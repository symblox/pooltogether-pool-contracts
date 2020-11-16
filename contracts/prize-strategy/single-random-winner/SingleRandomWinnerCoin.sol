// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import '../PeriodicPrizeStrategy.sol';
import '../../interface/ISponsor.sol';

/* solium-disable security/no-block-members */
/* only award external tokens*/
contract SingleRandomWinnerCoin is PeriodicPrizeStrategy {
  ISponsor public sponsor;

  function setSponsor(address _sponsor) external onlyOwner {
    sponsor = ISponsor(_sponsor);
  }

  function startAward() public override requireCanStartAward {
    if (address(sponsor) != address(0)) {
      sponsor.getReward();
    }
    super.startAward();
  }

  function _distribute(uint256 randomNumber) internal override {
    uint256 prize = prizePool.captureAwardBalance();
    address winner = ticket.draw(randomNumber);
    if (address(sponsor) != address(0)) {
      if (winner != address(0) && winner != sponsor.ticketHolder()) {
        _awardTickets(winner, prize);
        _awardAllExternalTokens(winner);
      }
    } else {
      if (winner != address(0)) {
        _awardTickets(winner, prize);
        _awardAllExternalTokens(winner);
      }
    }
  }
}
