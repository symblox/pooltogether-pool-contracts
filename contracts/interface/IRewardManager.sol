pragma solidity >=0.6.0 <0.7.0;

interface IRewardManager {
  function userInfo(uint256 _pid, address account) external view returns (uint256, uint256);

  function deposit(uint256 _pid, uint256 _amount) external returns (uint256);

  function withdraw(uint256 _pid, uint256 _amount) external returns (uint256);

  function getReward(uint256 _pid) external returns (uint256);

  function pendingSyx(uint256 _pid, address account) external view returns (uint256);

  function syx() external view returns (address);
}
