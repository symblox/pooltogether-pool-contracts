pragma solidity >=0.6.0 <0.7.0;
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol';

contract mockRewardPool {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  address public syx;

  function setSyx(address _syx) public {
    syx = _syx;
  }

  function userInfo(uint256 _pid, address account) external view returns (uint256, uint256) {
    return (0, 0);
  }

  function deposit(uint256 _pid, uint256 _amount) external returns (uint256) {
    return _amount;
  }

  function withdraw(uint256 _pid, uint256 _amount) external returns (uint256) {
    return _amount;
  }

  function getReward(uint256 _pid) external returns (uint256) {
    IERC20Upgradeable(syx).safeTransfer(msg.sender, 1 ether);
  }

  function pendingSyx(uint256 _pid, address account) external view returns (uint256) {
    return 1 ether;
  }
}
