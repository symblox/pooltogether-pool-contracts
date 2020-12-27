const { deployments } = require('@nomiclabs/buidler')
const { expect } = require('chai')
const buidler = require('@nomiclabs/buidler')
const { ethers } = require('ethers')
const { AddressZero } = ethers.constants
const { getEvents } = require('./helpers/getEvents')

const toWei = ethers.utils.parseEther

describe('StakePrizePoolBuilder', () => {
  let wallet

  let builder

<<<<<<< HEAD
  let reserveRegistry, trustedForwarder, singleRandomWinnerBuilder, stakePrizePoolProxyFactory, rngServiceMock, token

  let singleRandomWinnerConfig, stakePrizePoolConfig
=======
  let reserveRegistry,
      stakePrizePoolProxyFactory,
      token

  let stakePrizePoolConfig
>>>>>>> v3.1.0

  beforeEach(async () => {
    ;[wallet] = await buidler.ethers.getSigners()
    await deployments.fixture()
    builder = await buidler.ethers.getContractAt(
      'StakePrizePoolBuilder',
      (await deployments.get('StakePrizePoolBuilder')).address,
      wallet
    )

<<<<<<< HEAD
    reserveRegistry = await deployments.get('ReserveRegistry')
    trustedForwarder = await deployments.get('TrustedForwarder')
    singleRandomWinnerBuilder = await deployments.get('SingleRandomWinnerBuilder')
    stakePrizePoolProxyFactory = await deployments.get('StakePrizePoolProxyFactory')
    rngServiceMock = await deployments.get('RNGServiceMock')
    token = await deployments.get('Dai')

    singleRandomWinnerConfig = {
      proxyAdmin: AddressZero,
      rngService: rngServiceMock.address,
      prizePeriodStart: 20,
      prizePeriodSeconds: 10,
      ticketName: 'Ticket',
      ticketSymbol: 'TICK',
      sponsorshipName: 'Sponsorship',
      sponsorshipSymbol: 'SPON',
      ticketCreditLimitMantissa: toWei('0.1'),
      ticketCreditRateMantissa: toWei('0.001'),
      externalERC20Awards: []
    }

=======
    reserveRegistry = (await deployments.get("ReserveRegistry"))
    stakePrizePoolProxyFactory = (await deployments.get("StakePrizePoolProxyFactory"))
    token = (await deployments.get("Dai"))

>>>>>>> v3.1.0
    stakePrizePoolConfig = {
      token: token.address,
      maxExitFeeMantissa: toWei('0.5'),
      maxTimelockDuration: 1000
    }
  })

  describe('initialize()', () => {
    it('should setup all factories', async () => {
      expect(await builder.reserveRegistry()).to.equal(reserveRegistry.address)
      expect(await builder.stakePrizePoolProxyFactory()).to.equal(stakePrizePoolProxyFactory.address)
    })
  })

  describe('createStakePrizePool()', () => {
    it('should allow a user to create a StakePrizePool', async () => {
      let tx = await builder.createStakePrizePool(stakePrizePoolConfig)
      let events = await getEvents(builder, tx)
      let event = events[0]

      expect(event.name).to.equal('PrizePoolCreated')

      const prizePool = await buidler.ethers.getContractAt('StakePrizePool', event.args.prizePool, wallet)

      expect(await prizePool.token()).to.equal(stakePrizePoolConfig.token)
      expect(await prizePool.maxExitFeeMantissa()).to.equal(stakePrizePoolConfig.maxExitFeeMantissa)
      expect(await prizePool.maxTimelockDuration()).to.equal(stakePrizePoolConfig.maxTimelockDuration)
      expect(await prizePool.owner()).to.equal(wallet._address)
      expect(await prizePool.prizeStrategy()).to.equal(AddressZero)
    })
  })
<<<<<<< HEAD

  describe('createSingleRandomWinner()', () => {
    it('should allow a user to create Stake Prize Pools with Single Random Winner strategy', async () => {
      let decimals = 18

      let tx = await builder.createSingleRandomWinner(stakePrizePoolConfig, singleRandomWinnerConfig, decimals)
      let events = await getEvents(tx)
      let prizePoolCreatedEvent = events.find(e => e.name == 'PrizePoolCreated')

      const prizePool = await buidler.ethers.getContractAt(
        'StakePrizePool',
        prizePoolCreatedEvent.args.prizePool,
        wallet
      )
      const prizeStrategy = await buidler.ethers.getContractAt(
        'SingleRandomWinnerHarness',
        await prizePool.prizeStrategy(),
        wallet
      )
      const ticketAddress = await prizeStrategy.ticket()
      const sponsorshipAddress = await prizeStrategy.sponsorship()

      expect(await prizeStrategy.ticket()).to.equal(ticketAddress)
      expect(await prizeStrategy.sponsorship()).to.equal(sponsorshipAddress)

      expect(await prizePool.token()).to.equal(stakePrizePoolConfig.token)
      expect(await prizePool.maxExitFeeMantissa()).to.equal(stakePrizePoolConfig.maxExitFeeMantissa)
      expect(await prizePool.maxTimelockDuration()).to.equal(stakePrizePoolConfig.maxTimelockDuration)
      expect(await prizePool.owner()).to.equal(wallet._address)

      expect(await prizeStrategy.prizePeriodStartedAt()).to.equal(singleRandomWinnerConfig.prizePeriodStart)
      expect(await prizeStrategy.prizePeriodSeconds()).to.equal(singleRandomWinnerConfig.prizePeriodSeconds)
      expect(await prizeStrategy.owner()).to.equal(wallet._address)
      expect(await prizeStrategy.rng()).to.equal(singleRandomWinnerConfig.rngService)

      const ticket = await buidler.ethers.getContractAt('Ticket', ticketAddress, wallet)
      expect(await ticket.name()).to.equal(singleRandomWinnerConfig.ticketName)
      expect(await ticket.symbol()).to.equal(singleRandomWinnerConfig.ticketSymbol)
      expect(await ticket.decimals()).to.equal(decimals)

      const sponsorship = await buidler.ethers.getContractAt('ControlledToken', sponsorshipAddress, wallet)
      expect(await sponsorship.name()).to.equal(singleRandomWinnerConfig.sponsorshipName)
      expect(await sponsorship.symbol()).to.equal(singleRandomWinnerConfig.sponsorshipSymbol)
      expect(await sponsorship.decimals()).to.equal(decimals)

      expect(await prizePool.maxExitFeeMantissa()).to.equal(stakePrizePoolConfig.maxExitFeeMantissa)
      expect(await prizePool.maxTimelockDuration()).to.equal(stakePrizePoolConfig.maxTimelockDuration)

      expect(await prizePool.creditPlanOf(ticket.address)).to.deep.equal([
        singleRandomWinnerConfig.ticketCreditLimitMantissa,
        singleRandomWinnerConfig.ticketCreditRateMantissa
      ])

      expect(await prizePool.creditPlanOf(sponsorship.address)).to.deep.equal([
        ethers.BigNumber.from('0'),
        ethers.BigNumber.from('0')
      ])
    })
  })
=======
>>>>>>> v3.1.0
})
