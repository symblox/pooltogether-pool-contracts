pragma solidity >=0.6.0 <0.7.0;
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol';

contract mockToken is ERC20UpgradeSafe {
  function initialize(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    uint256 initialSupply
  ) public virtual initializer {
    __ERC20_init(_name, _symbol);
    _setupDecimals(_decimals);
    mint(msg.sender, initialSupply);
  }

  receive() external payable {
    mint(msg.sender, msg.value * 1000);
  }

  function mint(address to, uint256 value) public returns (bool) {
    _mint(to, value);
    return true;
  }
}
