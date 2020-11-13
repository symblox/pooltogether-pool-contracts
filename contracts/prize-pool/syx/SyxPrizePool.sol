// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;
import '@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol';
import '../../interface/ISponsor.sol';
import '../../interface/IWvlx.sol';
import '../PrizePool.sol';

contract SyxPrizePool is PrizePool {
  using Address for address payable;

  IERC20 private stakeToken;
  ISponsor public sponsor;

  event SyxPrizePoolInitialized(address indexed stakeToken);

  function initialize(
    address _trustedForwarder,
    RegistryInterface _reserveRegistry,
    address[] memory _controlledTokens,
    uint256 _maxExitFeeMantissa,
    uint256 _maxTimelockDuration,
    IERC20 _stakeToken,
    address _sponsor
  ) public initializer {
    PrizePool.initialize(
      _trustedForwarder,
      _reserveRegistry,
      _controlledTokens,
      _maxExitFeeMantissa,
      _maxTimelockDuration
    );
    stakeToken = _stakeToken;
    sponsor = ISponsor(_sponsor);

    emit SyxPrizePoolInitialized(address(stakeToken));
  }

  receive() external payable {}

  /// @notice Determines whether the passed token can be transferred out as an external award.
  /// @dev Different yield sources will hold the deposits as another kind of token: such a Compound's cToken.  The
  /// prize strategy should not be allowed to move those tokens.
  /// @param _externalToken The address of the token to check
  /// @return True if the token may be awarded, false otherwise
  function _canAwardExternal(address _externalToken) internal override view returns (bool) {
    return address(stakeToken) != _externalToken;
  }

  /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
  /// @return The underlying balance of asset tokens
  function _balance() internal override returns (uint256) {
    return stakeToken.balanceOf(address(this));
  }

  function _token() internal override view returns (IERC20) {
    return stakeToken;
  }

  /// @notice Supplies asset tokens to the yield source.
  /// @param mintAmount The amount of asset tokens to be supplied
  function _supply(uint256 mintAmount) internal override {
    // no-op because nothing else needs to be done
  }

  /// @notice Redeems asset tokens from the yield source.
  /// @param redeemAmount The amount of yield-bearing tokens to be redeemed
  /// @return The actual amount of tokens that were redeemed.
  function _redeem(uint256 redeemAmount) internal override returns (uint256) {
    return redeemAmount;
  }

  function depositVlxTo(
    address to,
    uint256 amount,
    address controlledToken,
    address referrer
  ) external payable onlyControlledToken(controlledToken) canAddLiquidity(amount) nonReentrant {
    require(amount == msg.value, 'PrizePool/invalid-amount');
    address operator = _msgSender();

    _mint(to, amount, controlledToken, referrer);

    // Cast lpToken from address to address payable
    address payable recipient = address(uint160(address(_token())));
    recipient.sendValue(msg.value);
    _supply(amount);

    emit Deposited(operator, to, controlledToken, amount, referrer);
  }

  function withdrawInstantlyFrom(
    address from,
    uint256 amount,
    address controlledToken,
    uint256 maximumExitFee
  ) external override nonReentrant onlyControlledToken(controlledToken) returns (uint256) {
    (uint256 exitFee, uint256 burnedCredit) = _calculateEarlyExitFeeLessBurnedCredit(from, controlledToken, amount);
    require(exitFee <= maximumExitFee, 'PrizePool/exit-fee-exceeds-user-maximum');

    // burn the credit
    _burnCredit(from, controlledToken, burnedCredit);
    // burn the tickets
    ControlledToken(controlledToken).controllerBurnFrom(_msgSender(), from, amount);

    // redeem the tickets less the fee
    uint256 amountLessFee = amount.sub(exitFee);
    uint256 redeemed = _redeem(amountLessFee);

    //TODO: When the amount of WVLX available is less than the amount entered, only the available amount is withdrawn
    IWvlx(address(_token())).withdraw(redeemed);
    if (exitFee > 0) {
      _mint(address(sponsor), exitFee, controlledToken, address(0));
      sponsor.depositAll(controlledToken, 0);
    }
    msg.sender.transfer(redeemed);

    emit InstantWithdrawal(_msgSender(), from, controlledToken, amount, redeemed, exitFee);

    return exitFee;
  }

  /// @notice Sweep available timelocked balances to their owners.  The full balances will be swept to the owners.
  /// @param users An array of owner addresses
  /// @return The total amount of assets swept from the Prize Pool
  function _sweepTimelockBalances(address[] memory users) internal override returns (uint256) {
    address operator = _msgSender();

    uint256[] memory balances = new uint256[](users.length);

    uint256 totalWithdrawal;

    uint256 i;
    for (i = 0; i < users.length; i++) {
      address user = users[i];
      if (_unlockTimestamps[user] <= _currentTime()) {
        totalWithdrawal = totalWithdrawal.add(_timelockBalances[user]);
        balances[i] = _timelockBalances[user];
        delete _timelockBalances[user];
      }
    }

    // if there is nothing to do, just quit
    if (totalWithdrawal == 0) {
      return 0;
    }

    timelockTotalSupply = timelockTotalSupply.sub(totalWithdrawal);

    uint256 redeemed = _redeem(totalWithdrawal);

    for (i = 0; i < users.length; i++) {
      if (balances[i] > 0) {
        delete _unlockTimestamps[users[i]];
        uint256 shareMantissa = FixedPoint.calculateMantissa(balances[i], totalWithdrawal);
        uint256 transferAmount = FixedPoint.multiplyUintByMantissa(redeemed, shareMantissa);
        //TODO: When the amount of WVLX available is less than the amount entered, only the available amount is withdrawn
        IWvlx(address(_token())).withdraw(transferAmount);
        address(uint160(users[i])).transfer(transferAmount);
        emit TimelockedWithdrawalSwept(operator, users[i], balances[i], transferAmount);
      }
    }

    return totalWithdrawal;
  }
}
