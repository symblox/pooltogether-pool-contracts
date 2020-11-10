// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import '../PeriodicPrizeStrategy.sol';

/* solium-disable security/no-block-members */
/* only award external tokens*/
contract SingleRandomWinnerCoin is PeriodicPrizeStrategy {
  function _distribute(uint256 randomNumber) internal override {
    address winner = ticket.draw(randomNumber);
    if (winner != address(0)) {
      _awardAllExternalTokens(winner);
    }
  }
}
