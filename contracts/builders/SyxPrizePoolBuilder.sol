// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import './PrizePoolBuilder.sol';
import '../registry/RegistryInterface.sol';
import './SingleRandomWinnerCoinBuilder.sol';
import '../prize-pool/syx/SyxPrizePoolProxyFactory.sol';

/* solium-disable security/no-block-members */
contract SyxPrizePoolBuilder is PrizePoolBuilder {
  using SafeMath for uint256;
  using SafeCast for uint256;

  struct SyxPrizePoolConfig {
    IERC20 token;
    uint256 maxExitFeeMantissa;
    uint256 maxTimelockDuration;
  }

  RegistryInterface public reserveRegistry;
  SyxPrizePoolProxyFactory public syxPrizePoolProxyFactory;
  SingleRandomWinnerCoinBuilder public singleRandomWinnerCoinBuilder;
  address public trustedForwarder;

  constructor(
    RegistryInterface _reserveRegistry,
    address _trustedForwarder,
    SyxPrizePoolProxyFactory _syxPrizePoolProxyFactory,
    SingleRandomWinnerCoinBuilder _singleRandomWinnerCoinBuilder
  ) public {
    require(address(_reserveRegistry) != address(0), 'SyxPrizePoolBuilder/reserveRegistry-not-zero');
    require(
      address(_singleRandomWinnerCoinBuilder) != address(0),
      'SyxPrizePoolBuilder/single-random-winner-builder-not-zero'
    );
    require(
      address(_syxPrizePoolProxyFactory) != address(0),
      'SyxPrizePoolBuilder/syx-prize-pool-proxy-factory-not-zero'
    );
    reserveRegistry = _reserveRegistry;
    singleRandomWinnerCoinBuilder = _singleRandomWinnerCoinBuilder;
    trustedForwarder = _trustedForwarder;
    syxPrizePoolProxyFactory = _syxPrizePoolProxyFactory;
  }

  function _setupSingleRandomWinner(
    PrizePool prizePool,
    SingleRandomWinnerCoin singleRandomWinner,
    uint256 ticketCreditRateMantissa,
    uint256 ticketCreditLimitMantissa
  ) internal {
    address ticket = address(singleRandomWinner.ticket());

    prizePool.setPrizeStrategy(singleRandomWinner);

    prizePool.addControlledToken(ticket);
    prizePool.addControlledToken(address(singleRandomWinner.sponsorship()));

    prizePool.setCreditPlanOf(ticket, ticketCreditRateMantissa.toUint128(), ticketCreditLimitMantissa.toUint128());
  }

  function createSingleRandomWinner(
    SyxPrizePoolConfig calldata prizePoolConfig,
    SingleRandomWinnerCoinBuilder.SingleRandomWinnerConfig calldata prizeStrategyConfig,
    uint8 decimals
  ) external returns (SyxPrizePool) {
    SyxPrizePool prizePool = syxPrizePoolProxyFactory.create();

    SingleRandomWinnerCoin prizeStrategy = singleRandomWinnerCoinBuilder.createSingleRandomWinner(
      prizePool,
      prizeStrategyConfig,
      decimals,
      msg.sender
    );

    address[] memory tokens;

    prizePool.initialize(
      trustedForwarder,
      reserveRegistry,
      tokens,
      prizePoolConfig.maxExitFeeMantissa,
      prizePoolConfig.maxTimelockDuration,
      prizePoolConfig.token
    );

    _setupSingleRandomWinner(
      prizePool,
      prizeStrategy,
      prizeStrategyConfig.ticketCreditRateMantissa,
      prizeStrategyConfig.ticketCreditLimitMantissa
    );

    prizePool.transferOwnership(msg.sender);

    emit PrizePoolCreated(msg.sender, address(prizePool));

    return prizePool;
  }

  function createSyxPrizePool(SyxPrizePoolConfig calldata config) external returns (SyxPrizePool) {
    SyxPrizePool prizePool = syxPrizePoolProxyFactory.create();
    address[] memory tokens;

    prizePool.initialize(
      trustedForwarder,
      reserveRegistry,
      tokens,
      config.maxExitFeeMantissa,
      config.maxTimelockDuration,
      config.token
    );

    prizePool.transferOwnership(msg.sender);

    emit PrizePoolCreated(msg.sender, address(prizePool));

    return prizePool;
  }
}
