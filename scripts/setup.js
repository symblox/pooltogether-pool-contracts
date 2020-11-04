const buidler = require('@nomiclabs/buidler')
const { deployments } = require('@nomiclabs/buidler')

async function getEvents(tx) {
  let receipt = await buidler.ethers.provider.getTransactionReceipt(tx.hash)
  return receipt.logs.reduce((parsedEvents, log) => {
    try {
      parsedEvents.push(builder.interface.parseLog(log))
    } catch (e) {}
    return parsedEvents
  }, [])
}

const setup = async () => {
  const { ethers } = buidler
  const { AddressZero } = ethers.constants
  const toWei = ethers.utils.parseEther

  ;[wallet] = await ethers.getSigners()
  console.log(`Using wallet address: ${wallet._address}`)

  //   await deployments.fixture()
  builder = await ethers.getContractAt(
    'StakePrizePoolBuilder',
    (await deployments.get('StakePrizePoolBuilder')).address,
    wallet
  )
  rngServiceMock = await deployments.get('RNGServiceMock')
  token = await deployments.get('Dai')

  singleRandomWinnerConfig = {
    proxyAdmin: AddressZero,
    rngService: rngServiceMock.address,
    prizePeriodStart: 20,
    prizePeriodSeconds: 10,
    ticketName: 'pooled Velas',
    ticketSymbol: 'pVLX',
    sponsorshipName: 'Sponsorship',
    sponsorshipSymbol: 'SPON',
    ticketCreditLimitMantissa: toWei('0.1'),
    ticketCreditRateMantissa: toWei('0.001'),
    externalERC20Awards: []
  }

  stakePrizePoolConfig = {
    token: token.address,
    maxExitFeeMantissa: toWei('0.5'),
    maxTimelockDuration: 1000
  }
  let decimals = 18

  let tx = await builder.createSingleRandomWinner(stakePrizePoolConfig, singleRandomWinnerConfig, decimals)
  let events = await getEvents(tx)
  let prizePoolCreatedEvent = events.find(e => e.name == 'PrizePoolCreated')

  const prizePool = await ethers.getContractAt('StakePrizePool', prizePoolCreatedEvent.args.prizePool, wallet)
  console.log(`PrizePool address: ${prizePool.address}`)
  const prizeStrategy = await ethers.getContractAt('SingleRandomWinnerHarness', await prizePool.prizeStrategy(), wallet)
  const ticketAddress = await prizeStrategy.ticket()
  console.log({ ticketAddress })
  const sponsorshipAddress = await prizeStrategy.sponsorship()
  console.log({ sponsorshipAddress })
}

setup()
