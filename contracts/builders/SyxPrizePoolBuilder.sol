// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import './PrizePoolBuilder.sol';
import '../registry/RegistryInterface.sol';
import './SingleRandomWinnerCoinBuilder.sol';
import '../prize-pool/syx/SyxPrizePoolProxyFactory.sol';
import '../sponsor/SponsorProxyFactory.sol';

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
  SponsorProxyFactory public sponsorProxyFactory;
  address public trustedForwarder;

  event SponsorCreated(address indexed creator, address indexed sponsor);

  constructor(
    RegistryInterface _reserveRegistry,
    address _trustedForwarder,
    SyxPrizePoolProxyFactory _syxPrizePoolProxyFactory,
    SingleRandomWinnerCoinBuilder _singleRandomWinnerCoinBuilder,
    SponsorProxyFactory _sponsorProxyFactory
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
    sponsorProxyFactory = _sponsorProxyFactory;
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
    Sponsor sponsor = sponsorProxyFactory.create();

    SingleRandomWinnerCoin prizeStrategy = singleRandomWinnerCoinBuilder.createSingleRandomWinner(
      prizePool,
      prizeStrategyConfig,
      decimals,
      msg.sender,
      address(sponsor)
    );

    address[] memory tokens;

    prizePool.initialize(
      trustedForwarder,
      reserveRegistry,
      tokens,
      prizePoolConfig.maxExitFeeMantissa,
      prizePoolConfig.maxTimelockDuration,
      prizePoolConfig.token,
      address(sponsor)
    );

    _setupSingleRandomWinner(
      prizePool,
      prizeStrategy,
      prizeStrategyConfig.ticketCreditRateMantissa,
      prizeStrategyConfig.ticketCreditLimitMantissa
    );

    prizePool.transferOwnership(msg.sender);

    emit PrizePoolCreated(msg.sender, address(prizePool));
    emit SponsorCreated(msg.sender, address(sponsor));

    return prizePool;
  }

  function createSyxPrizePool(SyxPrizePoolConfig calldata config) external returns (SyxPrizePool) {
    SyxPrizePool prizePool = syxPrizePoolProxyFactory.create();
    Sponsor sponsor = sponsorProxyFactory.create();

    address[] memory tokens;

    prizePool.initialize(
      trustedForwarder,
      reserveRegistry,
      tokens,
      config.maxExitFeeMantissa,
      config.maxTimelockDuration,
      config.token,
      address(sponsor)
    );

    prizePool.transferOwnership(msg.sender);

    emit PrizePoolCreated(msg.sender, address(prizePool));
    emit SponsorCreated(msg.sender, address(sponsor));

    return prizePool;
  }
}
