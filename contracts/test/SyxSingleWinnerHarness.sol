pragma solidity >=0.6.0 <0.7.0;

import "../prize-strategy/syx-single-winner/SyxSingleWinner.sol";

/* solium-disable security/no-block-members */
contract SyxSingleWinnerHarness is SyxSingleWinner {
  uint256 internal time;

  function setCurrentTime(uint256 _time) external {
    time = _time;
  }

  function _currentTime() internal view override returns (uint256) {
    if (time > 0) {
      return time;
    } else {
      return block.timestamp;
    }
  }

  function setRngRequest(uint32 requestId, uint32 lockBlock) external {
    rngRequest.id = requestId;
    rngRequest.lockBlock = lockBlock;
  }
}
